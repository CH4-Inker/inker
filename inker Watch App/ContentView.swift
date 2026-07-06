import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var player: PlayerModel
    @StateObject private var gestures = MotionGestureManager()
    @State private var page = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Single fixed header — stays put across page swipes instead of
                // each page carrying its own (which duplicated during transitions).
                TopBar(
                    gesturesOn: gestures.isRunning,
                    onBadgeTap: { withAnimation { page = 1 } }
                )
                .padding(.horizontal)
                .padding(.top, -8)

                TabView(selection: $page) {
                    NowPlayingView(isActive: page == 0)
                        .tag(0)
                    ControlsView(gestures: gestures, isActive: page == 1)
                        .tag(1)
                }
                .tabViewStyle(.page)
            }
            .focusable(true)
            .digitalCrownRotation(
                Binding(
                    get: { Double(player.volume) },
                    set: {
                        player.setVolume(Float($0))
                        player.noteGesture(icon: "digitalcrown.arrow.counterclockwise", label: "Digital Crown", action: "Volume")
                    }
                ),
                from: 0, through: 1, by: 0.02,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
        }
        .onAppear { wireGestures() }
        .onDisappear { gestures.stop() }
    }

    /// Connect the motion engine's callbacks to the player, recording each as
    /// the "last gesture" shown on the Now Playing screen.
    private func wireGestures() {
        gestures.onPrevious = {
            player.previous()
            player.noteGesture(icon: "hand.draw.fill", label: "Flick", action: "Previous track")
        }
        gestures.onPlayPause = {
            player.togglePlayPause()
            player.noteGesture(icon: "waveform.path", label: "Shake", action: "Play / Pause")
        }
    }
}

#Preview {
    ContentView().environmentObject(PlayerModel())
}
