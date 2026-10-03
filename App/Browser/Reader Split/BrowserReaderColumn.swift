import SwiftUI
import Hanami

struct BrowserReaderColumn: View {

    let article: Article?

    var body: some View {
        if let article {
            ArticleDestinationView(article: article)
                .id(article.id)
        } else {
            ContentUnavailableView {
                Label(String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                      systemImage: "doc.text")
            } description: {
                Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
            }
        }
    }
}
