import AppKit
import Hanami

/// The right-click menu for a piece of content in the list.
struct ContentMenuBuilder {

    let feedManager: FeedManager
    let openInNewTab: (BrowserLocation) -> Void
    var moveToFolder: ((Article) -> Void)?

    func items(for article: Article) -> [NSMenuItem] {
        let isRead = feedManager.isRead(article)
        let isBookmarked = feedManager.isBookmarked(article)
        var items: [NSMenuItem] = [
            ActionMenuItem(
                String(localized: "Menu.OpenInNewTab", table: "Browser"),
                symbolName: "plus.square.on.square"
            ) {
                openInNewTab(.article(article.id))
            },
            .separator(),
            ActionMenuItem(
                String(localized: isRead ? "Article.MarkUnread" : "Article.MarkRead", table: "Articles"),
                symbolName: isRead ? "circle.fill" : "circle"
            ) {
                feedManager.toggleRead(article)
            },
            ActionMenuItem(
                String(localized: isBookmarked ? "Article.RemoveBookmark" : "Article.Bookmark", table: "Articles"),
                symbolName: isBookmarked ? "bookmark.slash" : "bookmark"
            ) {
                feedManager.toggleBookmark(article)
            }
        ]
        if isBookmarked, let moveToFolder {
            let moveTitle = String(localized: "Article.MoveToFolder", table: "Articles")
            items.append(ActionMenuItem(moveTitle, symbolName: "folder") {
                moveToFolder(article)
            })
        }
        guard let url = URL(string: article.url) else { return items }
        items += [
            .separator(),
            ActionMenuItem(String(localized: "Article.OpenInBrowser", table: "Articles"), symbolName: "safari") {
                NSWorkspace.shared.open(url)
            },
            ActionMenuItem(String(localized: "Article.CopyLink", table: "Articles"), symbolName: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
            },
            NSSharingServicePicker(items: [url]).standardShareMenuItem
        ]
        return items
    }
}
