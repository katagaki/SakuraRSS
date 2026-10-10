import Hanami
import SwiftUI

struct TodayRecentContentSection: View {

    let feedManager: FeedManager
    let actions: TodayActions
    let revisions: WindowDataRevisions
    @State private var articles: [Article] = []

    var body: some View {
        // Not a Group: it forwards .task to its children, so the load would never run while empty.
        VStack(spacing: 0) {
            if !articles.isEmpty {
                section
            }
        }
        .task(id: revisions.dataRevision + revisions.recentsRevision) {
            let unread = feedManager.articles(limit: 6, requireUnread: true)
            articles = unread.isEmpty ? feedManager.articles(limit: 6) : unread
        }
    }

    private var section: some View {
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
                        ContentContextMenu(article: article, feedManager: feedManager, actions: actions)
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
