import AppKit
import Hanami
import SwiftUI

/// Search, scope, sort and the collection actions on Bookmarks pages.
extension ContentListViewController {

    /// The page's content, searched and sorted on Bookmarks pages.
    func queriedArticles(for location: BrowserLocation) -> [Article] {
        let scope = location == .bookmarks ? bookmarkBrowsing.scope : .all
        let articles = ContentQuery(feedManager: feedManager, bookmarkScope: scope).articles(for: location)
        guard location.isBookmarksPage else { return articles }
        if !bookmarkBrowsing.query.isEmpty {
            bookmarkBrowsing.tagNamesByArticleID = (try? feedManager.database.bookmarkTagNamesByArticleID()) ?? [:]
        }
        return bookmarkBrowsing.apply(to: articles, feedManager: feedManager)
    }

    func showsBookmarkBar(for location: BrowserLocation) {
        bookmarkBar.isHidden = !location.isBookmarksPage
        bookmarkBar.rootView = BookmarkBrowsingBar(
            browsing: bookmarkBrowsing,
            showsScope: location == .bookmarks,
            onExport: { [weak self] in self?.exportBookmarks() },
            onRemoveReadBookmarks: { [weak self] in self?.confirmRemovingReadBookmarks() }
        )
    }

    func observeBookmarkBrowsing() {
        bookmarkBrowsingObserver = ChangeObserver { [weak self] in
            guard let browsing = self?.bookmarkBrowsing else { return }
            _ = (browsing.scope, browsing.searchText, browsing.sortOrder)
        } onChange: { [weak self] in
            guard let self, self.location?.isBookmarksPage == true else { return }
            self.reloadArticles(keepingSelection: true)
        }
    }

    func exportBookmarks() {
        presentSwiftUISheet(BookmarkExportSheet(), feedManager: feedManager)
    }

    /// The same confirmation iOS asks for.
    func confirmRemovingReadBookmarks() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "Bookmarks.DeleteAllRead", table: "Articles")
        alert.informativeText = String(localized: "Bookmarks.DeleteAllRead.Message", table: "Articles")
        alert.addButton(withTitle: String(localized: "Bookmarks.DeleteAllRead.Confirm", table: "Articles"))
            .hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Shared.Cancel"))
        alert.beginSheetModal(for: window) { [feedManager] response in
            guard response == .alertFirstButtonReturn else { return }
            MainActor.assumeIsolated {
                try? feedManager.database.removeReadBookmarks()
                feedManager.bumpDataRevision()
            }
        }
    }
}
