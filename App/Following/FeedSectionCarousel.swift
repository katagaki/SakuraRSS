import SwiftUI
import Hanami

struct FeedSectionCarousel: View {

    let feeds: [Feed]
    let openFeed: (Feed) -> Void
    @Binding var feedToEdit: Feed?
    @Binding var feedForRules: Feed?
    @Binding var feedToDelete: Feed?
    let editTransitionNamespace: Namespace.ID

    @ScaledMetric(relativeTo: .caption) private var minimumCellWidth: CGFloat = 72
    @State private var carouselWidth: CGFloat = 0

    private let cellSpacing: CGFloat = 12
    private let leadingInset: CGFloat = 16

    /// A fractional count leaves the last visible cell cut off, which is what
    /// signals that the row scrolls.
    private var cellWidth: CGFloat {
        guard carouselWidth > 0 else { return minimumCellWidth }
        let preferredWidth = cellWidth(showing: 4.2)
        if preferredWidth >= minimumCellWidth {
            return preferredWidth
        }
        return max(cellWidth(showing: 3.5), 0)
    }

    private func cellWidth(showing visibleCount: CGFloat) -> CGFloat {
        let gapsWidth = visibleCount.rounded(.down) * cellSpacing
        return (carouselWidth - leadingInset - gapsWidth) / visibleCount
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: cellSpacing) {
                ForEach(feeds) { feed in
                    // A Menu rather than a context menu: a List claims the
                    // first context menu in a row for the whole row.
                    Menu {
                        FollowingFeedGridContextMenu(
                            feed: feed,
                            feedToEdit: $feedToEdit,
                            feedForRules: $feedForRules,
                            feedToDelete: $feedToDelete
                        )
                    } label: {
                        FollowingFeedGridCell(
                            feed: feed,
                            editTransitionNamespace: editTransitionNamespace
                        )
                        .frame(width: cellWidth)
                    } primaryAction: {
                        openFeed(feed)
                    }
                    .buttonStyle(.plain)
                    .id(feed.id)
                }
            }
            .padding(.horizontal, leadingInset)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            carouselWidth = width
        }
    }
}
