import SwiftUI
import Hanami

struct BrowserRecentContentSection: View {

    private static let contentLimit = 6

    @Environment(FeedManager.self) private var feedManager

    private var articles: [Article] {
        let unread = feedManager.articles(limit: BrowserRecentContentSection.contentLimit, requireUnread: true)
        guard unread.isEmpty else { return unread }
        return feedManager.articles(limit: BrowserRecentContentSection.contentLimit)
    }

    var body: some View {
        // Read once: each read is a database query, and the rows below would
        // otherwise run it again for every divider they place.
        let articles = articles
        if !articles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BrowserStartPageSectionHeader(
                    title: String(localized: "StartPage.RecentContent", table: "Browser")
                )
                VStack(spacing: 0) {
                    ForEach(articles) { article in
                        NavigationLink(value: article) {
                            BrowserRecentContentRow(article: article)
                        }
                        .buttonStyle(.plain)
                        if article.id != articles.last?.id {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
                .padding(.vertical, 4)
                .compatibleGlassEffect(in: .rect(cornerRadius: 18))
            }
        }
    }
}
