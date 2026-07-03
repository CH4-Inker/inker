import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerModel
    @StateObject private var gestures = MotionGestureManager()

    @State private var motionEnabled = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {

                // Now playing
                VStack(spacing: 2) {
                    Text(player.currentTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text("Track \(indexLabel) of 4")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Transport row: previous / play-pause / next
                HStack(spacing: 16) {
                    Button { player.previous() } label: {
                        Image(systemName: "backward.fill")
                    }

                    // Play/Pause is the app's PRIMARY action, so the system
                    // Double Tap gesture triggers it (Series 9 / Ultra 2+).
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                    }
                    .handGestureShortcut(.primaryAction)

                    Button { player.next() } label: {
                        Image(systemName: "forward.fill")
                    }
                }
                .buttonStyle(.bordered)

                // Volume row
                HStack(spacing: 16) {
                    Button { player.volumeDown() } label: {
                        Image(systemName: "speaker.wave.1.fill")
                    }
                    Button { player.volumeUp() } label: {
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
                .buttonStyle(.bordered)

                ProgressView(value: Double(player.volume))
                    .tint(.green)

                // Motion gestures on/off (prevents accidental triggers when you
                // don't want them, e.g. while walking).
                Toggle("Motion gestures", isOn: $motionEnabled)
                    .font(.caption)
                    .onChange(of: motionEnabled) { _, on in
                        on ? gestures.start() : gestures.stop()
                    }

                if motionEnabled {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("flick → / ← : next / prev")
                        Text("double flick → / ← : vol +/-")
                        Text("shake : play / pause")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ---- On-watch debug panel ----
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(player.isBluetoothOutput ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text("Out: \(player.outputRouteName)")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    Text(player.lastEvent)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .onAppear { wireGestures() }
        .onDisappear { gestures.stop() }
    }

    private var indexLabel: String {
        // currentIndex is 0-based; show it 1-based.
        "\(player.trackTitles.firstIndex(of: player.currentTitle).map { $0 + 1 } ?? 1)"
    }

    /// Connect the motion engine's callbacks to the player.
    private func wireGestures() {
        gestures.onVolumeUp   = { player.volumeUp() }
        gestures.onVolumeDown = { player.volumeDown() }
        gestures.onNext       = { player.next() }
        gestures.onPrevious   = { player.previous() }
        gestures.onPlayPause  = { player.togglePlayPause() }
    }
}

#Preview {
    ContentView().environmentObject(PlayerModel())
}
