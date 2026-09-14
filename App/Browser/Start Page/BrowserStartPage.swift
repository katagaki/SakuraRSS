import SwiftUI
import Hanami

/// The new-tab landing: favourites, what this browser opens most, and the
/// freshest unread content.
struct BrowserStartPage: View {

    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                BrowserStartPageHeader()
                if feedManager.feeds.isEmpty {
                    BrowserStartPageEmptyState()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    BrowserFavouritesSection()
                    BrowserFrequentlyVisitedSection()
                    BrowserRecentContentSection()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .sakuraBackground()
    }
}
