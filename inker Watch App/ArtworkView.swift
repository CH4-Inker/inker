import SwiftUI
import UIKit

/// Cover art (from a track's embedded mp3 ID3 artwork), with a graceful
/// placeholder (music note on a tinted square/circle) when it has none.
struct ArtworkView: View {
    let image: UIImage?
    var size: CGFloat = 36
    var circle: Bool = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
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
