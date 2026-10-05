import SwiftUI
import Hanami

struct FeedSectionPageHeader: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.navigateToFeed) private var navigateToFeed
    let section: FeedSection
    @Binding var feedToEdit: Feed?
    @Binding var feedForRules: Feed?
    @Binding var feedToDelete: Feed?
    let editTransitionNamespace: Namespace.ID

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
            FeedSectionCarousel(
                feeds: feeds,
                openFeed: { feed in navigateToFeed?(feed) },
                feedToEdit: $feedToEdit,
                feedForRules: $feedForRules,
                feedToDelete: $feedToDelete,
                editTransitionNamespace: editTransitionNamespace
            )
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
