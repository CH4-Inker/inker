import Foundation
import AVFoundation
import Combine
import WatchKit

/// Owns the playlist and the AVAudioPlayer. All playback control goes through
/// here. Heavily logged — every action prints to the Xcode console so you can
/// trace what the app is doing. It also watches the audio ROUTE, so you can see
/// when the ESP32 (Bluetooth A2DP) becomes the active output vs. the watch.
@MainActor
final class PlayerModel: ObservableObject {

    private let trackFileNames = ["song1", "song2", "song3", "song4"]
    private let trackExtension = "mp3"
    let trackTitles = ["Track One", "Track Two", "Track Three", "Track Four"]

    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var volume: Float = 0.6

    /// Human-readable name of the current audio output (shown on screen).
    /// e.g. "Interactive Speaker" (ESP32) or "Speaker" (the watch itself).
    @Published private(set) var outputRouteName = "—"
    @Published private(set) var isBluetoothOutput = false

    /// Last thing that happened, shown on the watch for quick glance-debugging.
    @Published private(set) var lastEvent = "ready"

    private var audioPlayer: AVAudioPlayer?
    private let volumeStep: Float = 0.05

    init() {
        log("init")
        configureAudioSession()
        observeRouteChanges()
        updateRoute(reason: "startup")
        load(index: currentIndex, autoplay: false)
    }

    // MARK: - Logging helpers
    private func log(_ msg: String) { print("🎵 [Player] \(msg)") }
    private func setEvent(_ msg: String) { lastEvent = msg; log(msg) }

    // MARK: - Haptics (confirms every action — button OR gesture)
    private func haptic(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    // MARK: - Audio session
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
            log("audio session active (category=.playback)")
        } catch {
            log("❌ audio session error: \(error)")
        }
    }

    // MARK: - Route monitoring (which output is audio going to?)
    private func observeRouteChanges() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            let reasonValue = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) ?? 0
            Task { @MainActor in
                self?.updateRoute(reason: "change(\(reasonValue))")
            }
        }
    }

    private func updateRoute(reason: String) {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        if let out = outputs.first {
            outputRouteName = out.portName
            isBluetoothOutput = (out.portType == .bluetoothA2DP
                                 || out.portType == .bluetoothLE
                                 || out.portType == .bluetoothHFP)
            log("🎚️ route [\(reason)] -> '\(out.portName)' type=\(out.portType.rawValue) "
                + (isBluetoothOutput ? "✅ Bluetooth (ESP32?)" : "⚠️ NOT bluetooth"))
        } else {
            outputRouteName = "none"
            isBluetoothOutput = false
            log("🎚️ route [\(reason)] -> no outputs")
        }
    }

    // MARK: - Loading
    private func load(index: Int, autoplay: Bool) {
        guard trackFileNames.indices.contains(index) else { return }
        let name = trackFileNames[index]
        log("loading '\(name).\(trackExtension)' (autoplay=\(autoplay))")

        guard let url = Bundle.main.url(forResource: name, withExtension: trackExtension) else {
            setEvent("❌ MISSING FILE: \(name).\(trackExtension) — not added to target")
            return
        }
        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            audioPlayer = newPlayer
            currentIndex = index
            log("loaded '\(name)' duration=\(String(format: "%.1f", newPlayer.duration))s")
            if autoplay { play() } else { isPlaying = false }
        } catch {
            setEvent("❌ load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Transport
    func play() {
        let ok = audioPlayer?.play() ?? false
        isPlaying = ok
        updateRoute(reason: "play")
        haptic(.start)
        setEvent(ok ? "▶️ playing '\(currentTitle)' -> \(outputRouteName)"
                    : "❌ play() returned false")
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        haptic(.stop)
        setEvent("⏸️ paused")
    }

    func togglePlayPause() {
        log("togglePlayPause (was playing=\(isPlaying))")
        isPlaying ? pause() : play()
    }

    func next() {
        let newIndex = (currentIndex + 1) % trackFileNames.count
        haptic(.click)
        setEvent("⏭️ next -> track \(newIndex + 1)")
        load(index: newIndex, autoplay: true)
    }

    func previous() {
        let newIndex = (currentIndex - 1 + trackFileNames.count) % trackFileNames.count
        haptic(.click)
        setEvent("⏮️ previous -> track \(newIndex + 1)")
        load(index: newIndex, autoplay: true)
    }

    // MARK: - Volume
    func volumeUp() { haptic(.directionUp); setVolume(volume + volumeStep) }
    func volumeDown() { haptic(.directionDown); setVolume(volume - volumeStep) }

    func setVolume(_ newValue: Float) {
        let clamped = min(max(newValue, 0.0), 1.0)
        volume = clamped
        audioPlayer?.volume = clamped
        setEvent("🔊 volume \(Int(clamped * 100))%")
    }

    var currentTitle: String {
        trackTitles.indices.contains(currentIndex) ? trackTitles[currentIndex] : "—"
    }
}
