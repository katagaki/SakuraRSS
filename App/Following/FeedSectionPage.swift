import SwiftUI
import Hanami

/// A feed type's followed feeds as a carousel above that type's content.
struct FeedSectionPage: View {

    @Environment(FeedManager.self) private var feedManager
    let section: FeedSection
    @State private var feedToEdit: Feed?
    @State private var feedForRules: Feed?
    @State private var feedToDelete: Feed?
    @Namespace private var feedEditNamespace

    var body: some View {
        HomeSectionView(
            source: .section(section),
            leadingHeader: AnyView(FeedSectionPageHeader(
                section: section,
                feedToEdit: $feedToEdit,
                feedForRules: $feedForRules,
                feedToDelete: $feedToDelete,
                editTransitionNamespace: feedEditNamespace
            ))
        )
        .sheet(item: $feedToEdit) { feed in
            EditFeedSheet(feedID: feed.id)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: feedEditNamespace))
        }
        .sheet(item: $feedForRules) { feed in
            EditFeedSheet(feedID: feed.id, initialTab: .rules)
                .environment(feedManager)
                .navigationTransition(.zoom(sourceID: feed.id, in: feedEditNamespace))
        }
        .alert(
            String(localized: "FeedMenu.Unfollow.Title", table: "Feeds"),
            isPresented: Binding(
                get: { feedToDelete != nil },
                set: { if !$0 { feedToDelete = nil } }
            )
        ) {
            Button(String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"), role: .destructive) {
                if let feed = feedToDelete {
                    withAnimation(.smooth.speed(2.0)) {
                        try? feedManager.deleteFeed(feed)
                    }
                    feedToDelete = nil
                }
            }
            Button("Shared.Cancel", role: .cancel) {
                feedToDelete = nil
            }
        } message: {
            if let feed = feedToDelete {
                Text(String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds"))
            }
        }
    }
}
