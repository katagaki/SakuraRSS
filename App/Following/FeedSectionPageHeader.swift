import SwiftUI
import Hanami

struct FeedSectionPageHeader: View {

    @Environment(FeedManager.self) private var feedManager
    let section: FeedSection
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

    private var feeds: [Feed] {
        let isFocusEffective = feedManager.isFocusEffective
        let focused = feedManager.focusedFeedIDs
        let visibleFeeds = feedManager.feeds.filter {
            $0.feedSection == section && (!isFocusEffective || focused.contains($0.id))
        }
        return visibleFeeds.groupedByFeedSection()[section] ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.localizedTitle)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(feeds) { feed in
                        NavigationLink(value: feed) {
                            FollowingFeedGridCell(
                                feed: feed,
                                editTransitionNamespace: editTransitionNamespace
                            )
                            .frame(width: cellWidth)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            FollowingFeedGridContextMenu(
                                feed: feed,
                                feedToEdit: $feedToEdit,
                                feedForRules: $feedForRules,
                                feedToDelete: $feedToDelete
                            )
                        } preview: {
                            // Menu previews don't inherit the environment.
                            FollowingFeedGridCell(feed: feed)
                                .frame(width: cellWidth)
                                .padding(12)
                                .environment(feedManager)
                        }
                        // Keep .id after .contextMenu: lazy stacks reuse the menu
                        // interaction and can present another feed's menu.
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
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
