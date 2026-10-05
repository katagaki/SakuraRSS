import AppKit
import Hanami

/// Batching and Mark as Read on Scroll, which both follow the list's scrolling.
extension ContentListViewController {

    private static let loadMoreDistance = 5

    func observeScrolling(of scrollView: NSScrollView) {
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.listDidScroll()
            }
        }
    }

    /// The settings change from Settings while the page is open; the page
    /// starts over with them, as it would when opened again.
    func observePresentationSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.presentation.settings != .current else { return }
                self.reloadArticles(keepingSelection: false)
            }
        }
    }

    private func listDidScroll() {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound, visibleRows.length > 0 else { return }
        markRowsScrolledPast(upTo: visibleRows.location)
        if NSMaxRange(visibleRows) >= articles.count - Self.loadMoreDistance {
            loadMoreIfAvailable()
        }
    }

    /// Rows whose top has gone above the list's top since the last scroll.
    private func markRowsScrolledPast(upTo newFirstVisibleRow: Int) {
        defer { firstVisibleRow = newFirstVisibleRow }
        let marksOnScroll = DoomscrollingMode.effectiveScrollMarkAsRead(
            UserDefaults.standard.bool(forKey: "Display.ScrollMarkAsRead")
        )
        guard marksOnScroll, newFirstVisibleRow > firstVisibleRow else { return }
        for row in firstVisibleRow..<min(newFirstVisibleRow, articles.count) {
            let article = articles[row]
            if !feedManager.isRead(article) {
                feedManager.markReadOnScroll(article)
            }
        }
    }

    private func loadMoreIfAvailable() {
        guard presentation.canLoadMore(allArticles) else { return }
        presentation.loadMore(of: allArticles)
        applyRowChanges(to: presentation.present(allArticles))
        reloadVisibleRows()
    }
}
