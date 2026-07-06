import SwiftUI
import UIKit

/// Rounded-square cover art from the asset catalog, with a graceful placeholder
/// (music note on a tinted square) when the named image isn't present.
struct ArtworkView: View {
    let name: String
    var size: CGFloat = 36
    var circle: Bool = false

    var body: some View {
        Group {
            if let ui = UIImage(named: name) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.3))
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }

    private var shape: AnyShape {
        circle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}
