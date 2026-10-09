import SwiftUI
import Hanami

extension FollowingPage {

    @ViewBuilder
    var emptyStateOverlay: some View {
        if feedManager.feeds.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "FeedList.Empty.Title", table: "Feeds"),
                      systemImage: "newspaper")
            } description: {
                Text(String(localized: "FeedList.Empty.Description", table: "Feeds"))
            } actions: {
                Button(String(localized: "FeedList.Empty.AddFeed", table: "Feeds")) {
                    isPresentingAddFeedSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
