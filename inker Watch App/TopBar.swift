import SwiftUI

/// Shared header for the Now Playing and Controls pages: playlist button and a
/// Gesture ON/OFF badge (green when motion gestures armed, gray when off). No
/// clock — watchOS shows its own in the status bar, and a second would dupe it.
struct TopBar: View {
    var gesturesOn: Bool
    /// Optional: when set, the badge becomes a button (e.g. jump to the
    /// Controls page where the Motion gesture toggle lives).
    var onBadgeTap: (() -> Void)? = nil

    var body: some View {
        HStack {
            NavigationLink(destination: PlaylistView()) {
                Image(systemName: "music.note.list")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            Spacer()

            if let onBadgeTap {
                Button(action: onBadgeTap) { badge }
                    .buttonStyle(.plain)
            } else {
                badge
            }
        }
    }

    private var badge: some View {
        Text(gesturesOn ? "Gesture ON" : "Gesture OFF")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((gesturesOn ? Color.green : Color.gray).opacity(0.25))
            .foregroundStyle(gesturesOn ? .green : .gray)
            .clipShape(Capsule())
    }
}
