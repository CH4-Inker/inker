import SwiftUI

extension View {
    /// Apply `.handGestureShortcut(.primaryAction)` only when `on` — so the
    /// system Double Tap gesture binds to exactly one control on the currently
    /// visible page (two active primary actions at once is undefined).
    @ViewBuilder
    func primaryAction(_ on: Bool) -> some View {
        if on { self.handGestureShortcut(.primaryAction) } else { self }
    }
}

/// Thin rounded progress bar matching the design mockups.
///
/// `onSeek` (optional) makes it tappable: a tap anywhere reports the tapped
/// fraction (0…1), used by the Now Playing screen to seek within a track.
struct ThinBar: View {
    var value: Double            // 0…1 fill fraction
    var tint: Color = .white
    var height: CGFloat = 4
    var onSeek: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let fill = max(0, min(1, value))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * fill)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { g in
                        guard let onSeek else { return }
                        onSeek(g.location.x / geo.size.width)
                    }
            )
        }
        .frame(height: height)
    }
}
