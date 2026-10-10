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

    /// The settings change from Settings or the page's own menu while the
    /// page is open; the page starts over with them, as it would when opened again.
    func observePresentationSettings() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restartIfPresentationSettingsChanged()
            }
        }
        pagePreferencesObserver = NotificationCenter.default.addObserver(
            forName: FeedManager.pagePreferencesDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restartIfPresentationSettingsChanged()
            }
        }
    }

    private func restartIfPresentationSettingsChanged() {
        guard let location, presentation.settings != .current(for: location, in: feedManager) else { return }
        reloadArticles(keepingSelection: false)
    }

    private func listDidScroll() {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.location != NSNotFound, visibleRows.length > 0 else { return }
        markRowsScrolledPast(upTo: visibleRows.location)
        guard NSMaxRange(visibleRows) >= articles.count - Self.loadMoreDistance else { return }
        // `endUpdates` can scroll the list as rows resize; inserting rows from
        // inside it makes NSTableView throw, so loading more waits until it's done.
        if isApplyingRowChanges {
            DispatchQueue.main.async { [weak self] in
                self?.listDidScroll()
            }
        } else {
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
