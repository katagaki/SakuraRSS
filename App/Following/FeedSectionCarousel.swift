import SwiftUI
import Hanami

struct FeedSectionCarousel: View {

    let feeds: [Feed]
    let openFeed: (Feed) -> Void
    @Binding var feedToEdit: Feed?
    @Binding var feedForRules: Feed?
    @Binding var feedToDelete: Feed?
    let editTransitionNamespace: Namespace.ID

    private let cellWidth: CGFloat = 56
    private let cellSpacing: CGFloat = 10
    private let leadingInset: CGFloat = 16

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
    }
}
