#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct FeedDetailWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let feedID: Int64

    private var feed: Feed? {
        feedManager.feedsByID[feedID]
    }

    var body: some View {
        if let feed {
            DetachedFeedNavigationStack {
                FeedArticlesView(feed: feed)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
#endif
