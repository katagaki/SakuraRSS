import SwiftUI
import Hanami

struct BrowserFavouritesSection: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(BrowserFavourites.self) private var favourites

    private let columns = [GridItem(.adaptive(minimum: 78), spacing: 16)]

    private var feeds: [Feed] {
        favourites.resolvedFeeds(feedManager: feedManager)
    }

    var body: some View {
        if !feeds.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BrowserStartPageSectionHeader(
                    title: String(localized: "StartPage.Favourites", table: "Browser")
                )
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(feeds) { feed in
                        BrowserFavouriteCell(feed: feed)
                    }
                }
            }
        }
    }
}
