import SwiftUI

/// Pushed from the top-left icon on either page. Tapping a track loads and
/// plays it; tapping the currently-playing track toggles play/pause instead.
struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerModel

    var body: some View {
        List(player.trackTitles.indices, id: \.self) { i in
            let isCurrent = i == player.currentIndex

            Button {
                player.selectTrack(i)
            } label: {
                HStack(spacing: 8) {
                    // Playing row shows a speaker circle INSTEAD of the cover
                    // (switch, not overlay) so icons never stack.
                    if isCurrent {
                        Circle().fill(Color.brown.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                    .font(.caption)
                            )
                    } else {
                        ArtworkView(name: player.trackArtworks[i], circle: true)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        // Ellipsis (not marquee) here — scroll animation is
                        // unreliable inside lazy List rows.
                        Text(player.trackTitles[i])
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(player.trackArtists[i])
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
