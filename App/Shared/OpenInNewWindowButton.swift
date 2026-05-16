#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct OpenInNewWindowButton: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.openWindow) private var openWindow
    let article: Article

    var body: some View {
        Button {
            feedManager.markRead(article)
            openWindow(id: "ArticleWindow", value: article.id)
        } label: {
            Label(
                String(localized: "Article.OpenInNewWindow", table: "Articles"),
                systemImage: "macwindow.badge.plus"
            )
        }
    }
}
#endif
