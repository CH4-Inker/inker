import Foundation
import AVFoundation
import Combine
import WatchKit

/// Owns the playlist and the AVAudioPlayer. All playback control goes through
/// here. Heavily logged — every action prints to the Xcode console so you can
/// trace what the app is doing. It also watches the audio ROUTE, so you can see
/// when the ESP32 (Bluetooth A2DP) becomes the active output vs. the watch.
@MainActor
final class PlayerModel: NSObject, ObservableObject {

    private let trackFileNames = ["song1", "song2", "song3", "song4"]
    private let trackExtension = "mp3"
    let trackTitles = ["Track One", "A Very Long Song Name That Should Scroll", "Track Three", "Track Four"]
    let trackArtists = ["Unknown Artist", "Unknown Artist", "Unknown Artist", "Unknown Artist"]
    /// Asset-catalog image names for cover art. Add matching images to
    /// Assets.xcassets; missing ones fall back to a placeholder icon.
    let trackArtworks = ["cover1", "cover2", "cover3", "cover4"]

    @Published private(set) var currentIndex = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var volume: Float = 0.6
    @Published private(set) var currentTime: TimeInterval = 0

    /// Human-readable name of the current audio output (shown on screen).
    /// e.g. "Interactive Speaker" (ESP32) or "Speaker" (the watch itself).
    @Published private(set) var outputRouteName = "—"
    @Published private(set) var isBluetoothOutput = false

    /// Last thing that happened, shown on the watch for quick glance-debugging.
    @Published private(set) var lastEvent = "ready"

    /// Most recent gesture that drove playback (not plain button taps) — shown
    /// on the Now Playing screen and in the Gestures guide.
    struct GestureEvent {
        let icon: String
        let label: String
        let action: String
    }
    @Published private(set) var lastGesture = GestureEvent(icon: "hand.pinch", label: "Double Tap", action: "Next track")

    private var audioPlayer: AVAudioPlayer?
    private let volumeStep: Float = 0.05
    private var playbackTimer: Timer?

    override init() {
        super.init()
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
            newPlayer.delegate = self
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            audioPlayer = newPlayer
            currentIndex = index
            currentTime = 0
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
        startPlaybackTimer()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        haptic(.stop)
        setEvent("⏸️ paused")
        playbackTimer?.invalidate()
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.currentTime = self.audioPlayer?.currentTime ?? 0 }
        }
    }

    /// Seek within the current track (tap on the progress bar). `fraction` is
    /// 0…1 of the track duration.
    func seek(toFraction fraction: Double) {
        guard let audioPlayer else { return }
        let clamped = min(max(fraction, 0), 1)
        let target = clamped * audioPlayer.duration
        audioPlayer.currentTime = target
        currentTime = target
        setEvent("⏩ seek \(Int(clamped * 100))%")
    }

    /// Jump to a specific playlist entry (tap in the Playlist screen). Tapping
    /// the currently-playing track toggles play/pause instead of reloading it.
    func selectTrack(_ index: Int) {
        if index == currentIndex {
            togglePlayPause()
        } else {
            load(index: index, autoplay: true)
        }
    }

    /// Records the gesture that just drove playback, for the Now Playing
    /// screen's hint card and the Gestures guide. Only called from gesture
    /// sites (Double Tap / flick / shake / Crown), not plain button taps.
    func noteGesture(icon: String, label: String, action: String) {
        lastGesture = GestureEvent(icon: icon, label: label, action: action)
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

    var currentArtist: String {
        trackArtists.indices.contains(currentIndex) ? trackArtists[currentIndex] : "—"
    }

    var duration: TimeInterval {
        audioPlayer?.duration ?? 0
    }
}

// MARK: - AVAudioPlayerDelegate (auto-advance when a track ends)
extension PlayerModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard flag else { return }
            self.next()
        }
    }
}
