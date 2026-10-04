import Hanami
import SwiftUI

struct ReaderPane: View {

    let article: Article?
    let feed: Feed?
    let activity: BrowserPageActivity

    var body: some View {
        if let article {
            ReaderView(article: article, feed: feed, activity: activity)
                .id(article.id)
        } else {
            ContentUnavailableView(
                String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                systemImage: "doc.text",
                description: Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
            )
        }
    }
}
