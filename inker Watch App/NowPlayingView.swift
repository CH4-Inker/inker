import SwiftUI

/// First page: title/artist, seekable progress, and a card showing the last
/// gesture that drove playback — tap it to open the full Gestures guide.
struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerModel
    var isActive: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 2)

            VStack(spacing: 2) {
                Text(player.currentTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(player.currentArtist)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ThinBar(
                    value: player.duration > 0 ? player.currentTime / player.duration : 0,
                    tint: .white,
                    onSeek: { player.seek(toFraction: $0) }
                )
                HStack {
                    Text(timeString(player.currentTime))
                    Spacer()
                    Text(timeString(player.duration))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 2)

            NavigationLink(destination: GestureGuideView()) {
                HStack(spacing: 10) {
                    Image(systemName: player.lastGesture.icon)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(player.lastGesture.label)
                            .font(.footnote.bold())
                        Text(player.lastGesture.action)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.brown.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .padding(.bottom, 8)
        // Tiny (1pt, invisible) primary-action target so the system Double Tap
        // gesture triggers Next on THIS page too. Kept 1pt so the Double Tap
        // highlight doesn't draw a big blob over the screen. (handGestureShortcut
        // only fires for the primary action on the currently-visible page; the
        // Controls page has its own on the Next button.)
        .overlay(alignment: .top) {
            Button {
                player.next()
                player.noteGesture(icon: "hand.pinch", label: "Double Tap", action: "Next track")
            } label: { Color.clear.frame(width: 1, height: 1) }
            .buttonStyle(.plain)
            .primaryAction(isActive)
            .allowsHitTesting(false)
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#Preview {
    NavigationStack { NowPlayingView().environmentObject(PlayerModel()) }
}
