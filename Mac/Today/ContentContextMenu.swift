import Hanami
import SwiftUI

/// The same actions as the content list's right-click menu, for Today's cards
/// and rows.
struct ContentContextMenu: View {

    let article: Article
    let feedManager: FeedManager
    let actions: TodayActions

    var body: some View {
        let isRead = feedManager.isRead(article)
        let isBookmarked = feedManager.isBookmarked(article)
        Button(String(localized: "Menu.OpenInNewTab", table: "Browser"), systemImage: "plus.square.on.square") {
            actions.openInNewTab(.article(article.id))
        }
        Divider()
        Button(
            String(localized: isRead ? "Article.MarkUnread" : "Article.MarkRead", table: "Articles"),
            systemImage: isRead ? "circle.fill" : "circle"
        ) {
            feedManager.toggleRead(article)
        }
        Button(
            String(localized: isBookmarked ? "Article.RemoveBookmark" : "Article.Bookmark", table: "Articles"),
            systemImage: isBookmarked ? "bookmark.slash" : "bookmark"
        ) {
            feedManager.toggleBookmark(article)
        }
        if isBookmarked {
            Button(String(localized: "Article.BookmarkDetails", table: "Articles"), systemImage: "pencil") {
                actions.showBookmarkDetails(article)
            }
            Button(String(localized: "Article.MoveToFolder", table: "Articles"), systemImage: "folder") {
                actions.moveToFolder(article)
            }
        }
        if let url = URL(string: article.url) {
            Divider()
            Button(String(localized: "Article.OpenInBrowser", table: "Articles"), systemImage: "safari") {
                NSWorkspace.shared.open(url)
            }
            Button(String(localized: "Article.CopyLink", table: "Articles"), systemImage: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
            }
            ShareLink(item: url)
        }
    }
}
