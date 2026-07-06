import SwiftUI

/// Second page: transport buttons, volume, and the Motion gesture toggle.
struct ControlsView: View {
    @EnvironmentObject private var player: PlayerModel
    @ObservedObject var gestures: MotionGestureManager
    var isActive: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 2)

            // Transport: outlined circular buttons, center one larger.
            HStack(spacing: 14) {
                CircleButton(icon: "backward.fill", size: 44) {
                    player.previous()
                }

                CircleButton(icon: player.isPlaying ? "pause.fill" : "play.fill", size: 60, iconScale: 0.5) {
                    player.togglePlayPause()
                }

                // Next is the app's PRIMARY action, so the system Double
                // Tap gesture triggers it (Series 9 / Ultra 2+).
                CircleButton(icon: "forward.fill", size: 44) {
                    player.next()
                    player.noteGesture(icon: "hand.pinch", label: "Double Tap", action: "Next track")
                }
                .primaryAction(isActive)
            }

            // Volume: speaker icons flanking a thin bar (also Crown-controlled).
            HStack(spacing: 8) {
                Button { player.volumeDown() } label: {
                    Image(systemName: "speaker.fill")
                }
                .buttonStyle(.plain)

                ThinBar(value: Double(player.volume), tint: .white)

                Button { player.volumeUp() } label: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                .buttonStyle(.plain)
            }
            .font(.footnote)

            Spacer(minLength: 2)

            Toggle("Motion gesture", isOn: Binding(
                get: { gestures.isRunning },
                set: { $0 ? gestures.start() : gestures.stop() }
            ))
            .font(.caption)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

/// Outlined circular transport button matching the design mockup.
private struct CircleButton: View {
    let icon: String
    let size: CGFloat
    var iconScale: CGFloat = 0.38
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * iconScale))
                .frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { ControlsView(gestures: MotionGestureManager()).environmentObject(PlayerModel()) }
}
