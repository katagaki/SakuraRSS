import Hanami
import SwiftUI

struct AddressFollowingFeedCell: View {

    let feed: Feed
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            FeedIconView(feed: feed, size: 44)
                .onHover { isHovering = $0 }
            Text(feed.title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: 80)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(.rect)
                .onHover { isHovering = $0 }
        }
        .brightness(isHovering ? 0.08 : 0)
    }
}
