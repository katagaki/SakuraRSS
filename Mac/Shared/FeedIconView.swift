import Hanami
import SwiftUI

/// A feed's icon, falling back to its initials, shaped the way iOS shapes it.
struct FeedIconView: View {

    let feed: Feed
    let size: CGFloat
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quinary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .contentShape(shape)
        .task(id: feed.id) {
            icon = await Iconography.shared.icon(for: feed)
                ?? InitialsAvatar.renderToImage(name: feed.title, size: size * 2)
        }
    }

    private var shape: AnyShape {
        feed.isCircleIcon ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}
