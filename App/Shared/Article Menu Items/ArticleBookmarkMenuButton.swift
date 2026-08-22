import Hanami
import SwiftUI

struct ArticleBookmarkMenuButton: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    var body: some View {
        let isBookmarked = feedManager.isBookmarked(article)
        Button {
            feedManager.toggleBookmark(article)
        } label: {
            Label(
                isBookmarked
                    ? String(localized: "Article.RemoveBookmark", table: "Articles")
                    : String(localized: "Article.Bookmark", table: "Articles"),
                systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            )
        }
    }
}
