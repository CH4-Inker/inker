import Foundation
import CoreMotion
import WatchKit
import Combine

/// Motion-gesture engine (whole-wrist motion only — finger tracking isn't
/// possible on Apple Watch). Detects:
///
///   • Single flick RIGHT  -> next
///   • Single flick LEFT   -> previous
///   • Double flick RIGHT  -> volume up
///   • Double flick LEFT   -> volume down
///   • Shake               -> play / pause
///
/// A "flick" is a sharp yaw rotation (rotationRate.z). A "shake" is repeated
/// linear acceleration reversals (userAcceleration magnitude), so the two are
/// detected from different signals and don't fight each other.
///
/// Single vs. double works like a double-click: on the first flick we wait a
/// short window to see if a second same-direction flick follows. This means a
/// SINGLE flick fires only after `doubleWindow` elapses — an unavoidable small
/// delay, the same tradeoff a mouse double-click has.
///
/// Haptics fire the instant a gesture is recognised (via PlayerModel actions),
/// so you feel confirmation on your wrist.
@MainActor
final class MotionGestureManager: NSObject, ObservableObject {

    // Wired to PlayerModel by ContentView.
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onPlayPause: (() -> Void)?

    @Published private(set) var isRunning = false

    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    private var runtimeSession: WKExtendedRuntimeSession?

    // MARK: - Tunable thresholds (adjust on your own wrist)

    // Flick (rotational / yaw)
    private let flickThreshold: Double   = 3.5   // rad/s yaw spike to count as a flick
    private let flickRefractory: TimeInterval = 0.20 // ignore new flick edges this long after one
    private let doubleWindow: TimeInterval    = 0.45 // max gap between 2 flicks to be a "double"

    // Shake (linear acceleration, back-and-forth)
    private let shakeThreshold: Double = 2.2     // g, peak magnitude to count a shake "peak"
    private let shakeReset: Double     = 1.0     // g, must fall below this between peaks (hysteresis)
    private let shakePeaksNeeded       = 3       // this many peaks within the window => shake
    private let shakeWindow: TimeInterval   = 0.6
    private let shakeCooldown: TimeInterval = 1.0

    // MARK: - Internal state
    private var lastFlickEdge: Date = .distantPast
    private var pendingFlickDir: Int = 0            // 0 none, +1 right, -1 left
    private var pendingFlickTime: Date = .distantPast

    private var shakePeakTimes: [Date] = []
    private var shakeArmed = true
    private var lastShakeFire: Date = .distantPast

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
        log("started. flick=nav, double-flick=volume, shake=play/pause")
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        pendingFlickDir = 0
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
            shakePeakTimes.append(now)
            shakePeakTimes = shakePeakTimes.filter { now.timeIntervalSince($0) <= shakeWindow }
            if shakePeakTimes.count >= shakePeaksNeeded,
               now.timeIntervalSince(lastShakeFire) > shakeCooldown {
                lastShakeFire = now
                shakePeakTimes.removeAll()
                pendingFlickDir = 0                 // cancel any pending flick
                fire(.playPause)
                return
            }
        } else if mag < shakeReset {
            shakeArmed = true                       // re-arm once motion settles
        }

        // ---------- Resolve a pending SINGLE flick if the window expired ----------
        if pendingFlickDir != 0,
           now.timeIntervalSince(pendingFlickTime) > doubleWindow {
            let dir = pendingFlickDir
            pendingFlickDir = 0
            fire(dir > 0 ? .next : .previous)       // it was a single
        }

        // ---------- FLICK (rotational / yaw) ----------
        let yaw = data.rotationRate.z
        if abs(yaw) > flickThreshold,
           now.timeIntervalSince(lastFlickEdge) > flickRefractory {
            lastFlickEdge = now
            let dir = yaw > 0 ? 1 : -1

            if pendingFlickDir == dir,
               now.timeIntervalSince(pendingFlickTime) <= doubleWindow {
                // Second flick, same direction => DOUBLE
                pendingFlickDir = 0
                fire(dir > 0 ? .volumeUp : .volumeDown)
            } else {
                // If an OPPOSITE flick was pending, resolve it now as a single.
                if pendingFlickDir != 0 {
                    let old = pendingFlickDir
                    fire(old > 0 ? .next : .previous)
                }
                pendingFlickDir = dir               // start waiting for a possible double
                pendingFlickTime = now
            }
        }
    }

    // MARK: - Fire actions

    private enum Action { case next, previous, volumeUp, volumeDown, playPause }

    private func fire(_ action: Action) {
        switch action {
        case .next:       log("single flick RIGHT -> next");        onNext?()
        case .previous:   log("single flick LEFT  -> previous");    onPrevious?()
        case .volumeUp:   log("double flick RIGHT -> volume up");   onVolumeUp?()
        case .volumeDown: log("double flick LEFT  -> volume down"); onVolumeDown?()
        case .playPause:  log("SHAKE -> play/pause");               onPlayPause?()
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
