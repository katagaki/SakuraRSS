import Hanami
import SwiftUI

struct TodayRecentContentSection: View {

    let feedManager: FeedManager
    let actions: TodayActions

    private var articles: [Article] {
        let unread = feedManager.articles(limit: 6, requireUnread: true)
        return unread.isEmpty ? feedManager.articles(limit: 6) : unread
    }

    var body: some View {
        let articles = articles
        if !articles.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "StartPage.RecentContent", table: "Browser"))
                    .font(.title3)
                    .fontWeight(.bold)
                VStack(spacing: 0) {
                    ForEach(articles) { article in
                        Button {
                            actions.open(.article(article.id))
                        } label: {
                            TodayRecentContentRow(
                                article: article,
                                feedTitle: feedManager.feedsByID[article.feedID]?.title
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            TodayOpenInNewTabButton(location: .article(article.id), actions: actions)
                        }
                        if article.id != articles.last?.id {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(.quinary, in: .rect(cornerRadius: 14))
            }
        }
    }
}
