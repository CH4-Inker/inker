import Foundation
import CoreMotion
import WatchKit
import Combine

/// Motion-gesture engine (whole-wrist motion only — finger tracking isn't
/// possible on Apple Watch). Detects:
///
///   • Flick (either direction) -> previous
///   • Shake                    -> play / pause
///
/// Next comes from the system Double Tap hand gesture (wired directly in
/// ContentView via `.handGestureShortcut`), and volume comes from the
/// Digital Crown — neither goes through this engine.
///
/// A "flick" is a sharp pitch rotation (rotationRate.x — wrist tilting up or
/// down); either direction fires the same action, so there's no asymmetry
/// concern here. It uses the same armed/reset hysteresis as shake below: a
/// single continuous hand rotation must drop back below `flickReset` before
/// it can fire again, so casually rotating your wrist doesn't fire Previous
/// more than once (or at all, if it doesn't cross `flickThreshold`). A
/// "shake" is repeated linear acceleration reversals (userAcceleration
/// magnitude), detected from a different signal so it doesn't fight the flick.
///
/// Haptics fire the instant a gesture is recognised (via PlayerModel actions),
/// so you feel confirmation on your wrist.
@MainActor
final class MotionGestureManager: NSObject, ObservableObject {

    // Wired to PlayerModel by ContentView.
    var onPrevious: (() -> Void)?
    var onPlayPause: (() -> Void)?

    @Published private(set) var isRunning = false

    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private var runtimeSession: WKExtendedRuntimeSession?

    // MARK: - Tunable thresholds (adjust on your own wrist)

    // Flick (rotational / pitch — wrist tilt up/down)
    private let flickThreshold: Double   = 12.0  // rad/s pitch spike to count as a flick — needs a genuinely fast wrist snap
    private let flickReset: Double        = 4.0   // rad/s, must fall below this before another flick can fire (hysteresis)
    private let flickRefractory: TimeInterval = 0.35 // minimum time between flicks, even if reset briefly
    private let flickCalmAccel: Double    = 1.2   // g, flick only fires if linear accel is BELOW this (shake is well above) — keeps a shake from also firing a flick
    private let flickShakeLockout: TimeInterval = 0.5 // ignore flick this long after any shake peak

    // Shake (linear acceleration, back-and-forth)
    private let shakeThreshold: Double = 2.2     // g, peak magnitude to count a shake "peak"
    private let shakeReset: Double     = 1.0     // g, must fall below this between peaks (hysteresis)
    private let shakePeaksNeeded       = 3       // this many peaks within the window => shake
    private let shakeWindow: TimeInterval   = 0.6
    private let shakeCooldown: TimeInterval = 1.0

    // MARK: - Internal state
    private var lastFlickEdge: Date = .distantPast
    private var flickArmed = true
    private var flickPeakThisEvent: Double = 0

    private var shakePeakTimes: [Date] = []
    private var shakeArmed = true
    private var lastShakeFire: Date = .distantPast
    private var lastShakePeak: Date = .distantPast

    private func log(_ m: String) { print("🖐️ [Gesture] \(m)") }

    // MARK: - Lifecycle

    func start() {
        guard motion.isDeviceMotionAvailable else {
            log("❌ device motion NOT available (Simulator? use a real watch)")
            return
        }
        guard !isRunning else { return }

        startRuntimeSession()

        motion.deviceMotionUpdateInterval = 1.0 / 50.0   // 50 Hz
        queue.maxConcurrentOperationCount = 1
        motion.startDeviceMotionUpdates(to: queue) { [weak self] data, error in
            if let error { print("🖐️ [Gesture] update error: \(error)") }
            guard let self, let data else { return }
            Task { @MainActor in self.process(motion: data) }
        }
        isRunning = true
        WKInterfaceDevice.current().play(.start)   // "armed" confirmation
        log("started. flick=previous, shake=play/pause")
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        flickArmed = true
        flickPeakThisEvent = 0
        shakePeakTimes.removeAll()
        runtimeSession?.invalidate()
        runtimeSession = nil
        isRunning = false
        WKInterfaceDevice.current().play(.stop)
        log("stopped")
    }

    // MARK: - Core processing (called ~50x/sec)

    private func process(motion data: CMDeviceMotion) {
        let now = Date()

        // ---------- SHAKE (checked first; wins over flick this frame) ----------
        let a = data.userAcceleration
        let mag = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()

        if mag > shakeThreshold, shakeArmed {
            shakeArmed = false
            lastShakePeak = now
            shakePeakTimes.append(now)
            shakePeakTimes = shakePeakTimes.filter { now.timeIntervalSince($0) <= shakeWindow }
            if shakePeakTimes.count >= shakePeaksNeeded,
               now.timeIntervalSince(lastShakeFire) > shakeCooldown {
                lastShakeFire = now
                shakePeakTimes.removeAll()
                fire(.playPause)
                return
            }
        } else if mag < shakeReset {
            shakeArmed = true                       // re-arm once motion settles
        }

        // ---------- FLICK (rotational / pitch) -> previous, either direction ----------
        // Hysteresis (armed/reset), same as shake: a single continuous rotation
        // only fires once, since it must drop back below `flickReset` before
        // another flick can be recognised — otherwise a normal, sustained hand
        // turn can stay above threshold long enough to fire repeatedly.
        let pitch = abs(data.rotationRate.x)
        flickPeakThisEvent = max(flickPeakThisEvent, pitch)

        // A shake also rotates the wrist, so a flick must be a CALM rotation:
        // low linear acceleration right now (mag < flickCalmAccel) and not
        // within the lockout window after a recent shake peak. That's what
        // separates a deliberate still-arm tilt from a shake.
        let calm = mag < flickCalmAccel
            && now.timeIntervalSince(lastShakePeak) > flickShakeLockout

        if pitch > flickThreshold, flickArmed, calm,
           now.timeIntervalSince(lastFlickEdge) > flickRefractory {
            flickArmed = false
            lastFlickEdge = now
            fire(.previous)
        } else if pitch < flickReset {
            if flickPeakThisEvent > 0.5 {
                // Logged for EVERY hand movement, not just ones that fire, so you
                // can read real peak values off the console and pick a
                // `flickThreshold` that separates casual movement from a real
                // flick on your own wrist.
                log("hand movement settled, peak rotationRate.x = \(String(format: "%.2f", flickPeakThisEvent)) rad/s (threshold=\(flickThreshold))")
            }
            flickPeakThisEvent = 0
            flickArmed = true                        // re-arm once motion settles
        }
    }

    // MARK: - Fire actions

    private enum Action { case previous, playPause }

    private func fire(_ action: Action) {
        switch action {
        case .previous:  log("flick -> previous");     onPrevious?()
        case .playPause: log("SHAKE -> play/pause");   onPlayPause?()
        }
        // Note: the confirming haptic is played inside the PlayerModel action,
        // so both buttons and gestures feel identical feedback.
    }

    // MARK: - Extended runtime (keeps sensors alive with screen off)

    private func startRuntimeSession() {
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        runtimeSession = session
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate
extension MotionGestureManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ s: WKExtendedRuntimeSession) {}
    nonisolated func extendedRuntimeSessionWillExpire(_ s: WKExtendedRuntimeSession) {}
    nonisolated func extendedRuntimeSession(
        _ s: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {}
}
