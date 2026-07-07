import SwiftUI

/// Pushed from the top-left icon on either page. Tapping a track loads and
/// plays it; tapping the currently-playing track toggles play/pause instead.
struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerModel

    var body: some View {
        List(Array(player.tracks.enumerated()), id: \.element.id) { i, track in
            let isCurrent = i == player.currentIndex

            Button {
                player.selectTrack(i)
            } label: {
                HStack(spacing: 8) {
                    ArtworkView(image: track.artwork, circle: true)
                        .overlay {
                            if isCurrent {
                                ZStack {
                                    Circle().fill(.black.opacity(0.45))
                                    Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                        .font(.caption)
                                }
                            }
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        // Ellipsis (not marquee) here — scroll animation is
                        // unreliable inside lazy List rows.
                        Text(track.title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(track.artist)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isCurrent ? Color.brown.opacity(0.35) : Color.clear)
            )
        }
        .navigationTitle("My Playlist")
    }
}

#Preview {
    NavigationStack { PlaylistView().environmentObject(PlayerModel()) }
}
