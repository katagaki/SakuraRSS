import SwiftUI

/// Tracks which article IDs are visible when Hide Viewed Content is on, and
/// holds back articles that arrive during a refresh until the user accepts
/// them via the refresh prompt button.
struct ArticleVisibilityTracker {
    var visibleIDs: Set<Int64>?
    /// Article IDs that arrived during the most recent refresh and haven't
    /// been released yet. Filtered out of the displayed list until the user
    /// taps the refresh prompt.
    var pendingIDs: Set<Int64> = []
    /// True once a backwards pagination produced no new unread articles, so
    /// the load-more sentinel can be hidden until the next refresh / mode change.
    var hasReachedEnd: Bool = false
    private var preRefreshIDs: Set<Int64> = []
    /// Highest article ID seen at refresh start. Articles inserted during
    /// the refresh land with IDs above this (sqlite autoincrement); pre-existing
    /// articles surfaced by load-more sit at or below it.
    private var preRefreshMaxID: Int64 = .max
    /// Pre-refresh article snapshot, kept so count-based queries don't go empty
    /// when newly inserted articles push the originals out of the top-N window.
    private var preRefreshSnapshot: [Article] = []
    private var activeRefreshCount: Int = 0

    var hasPendingRefresh: Bool { !pendingIDs.isEmpty }

    func filter(_ articles: [Article], isEnabled: Bool) -> [Article] {
        var result = articles
        // Hide arrivals that land before `endRefresh` moves them to `pendingIDs`.
        // Pre-existing articles (id <= preRefreshMaxID) pass through so load-more
        // during a refresh still surfaces older content. The snapshot is unioned
        // back in so count-based queries (e.g. Doomscroll's items25) don't go
        // empty when new arrivals take over the top-N.
        if activeRefreshCount > 0 {
            let liveIDs = Set(result.map(\.id))
            for snapshot in preRefreshSnapshot where !liveIDs.contains(snapshot.id) {
                result.append(snapshot)
            }
            result = result.filter { $0.id <= preRefreshMaxID }
            result.sort { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
        }
        if isEnabled, let visibleIDs {
            result = result.filter { visibleIDs.contains($0.id) }
        }
        if !pendingIDs.isEmpty {
            result = result.filter { !pendingIDs.contains($0.id) }
        }
        return result
    }

    mutating func capture(from articles: [Article], isEnabled: Bool) {
        hasReachedEnd = false
        guard isEnabled else {
            visibleIDs = nil
            return
        }
        visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
    }

    /// Returns true if at least one new unread ID was added. Pending IDs are
    /// excluded so unaccepted refresh content can't fake growth.
    @discardableResult
    mutating func extend(from articles: [Article], isEnabled: Bool) -> Bool {
        guard isEnabled else {
            visibleIDs = nil
            return false
        }
        let unreadIDs = Set(articles.filter { !$0.isRead }.map(\.id))
            .subtracting(pendingIDs)
        let previous = visibleIDs ?? []
        let merged = previous.union(unreadIDs)
        let didGrow = merged.count > previous.count
        visibleIDs = merged
        return didGrow
    }

    /// Snapshots the current article IDs so a later `endRefresh` can compute
    /// what arrived during the refresh. When `recaptureVisible` is true and
    /// Hide Viewed Content is on, the visible set is rebuilt from currently
    /// unread articles so newly-read items disappear immediately, appropriate
    /// for an explicit pull-to-refresh. Background refreshes should pass false
    /// so an in-progress reading session doesn't have its visible items yanked
    /// away when an unrelated refresh runs.
    mutating func beginRefresh(
        from articles: [Article],
        isEnabled: Bool,
        recaptureVisible: Bool = false
    ) {
        if activeRefreshCount == 0 {
            hasReachedEnd = false
            preRefreshSnapshot = articles
            preRefreshIDs = Set(articles.map(\.id)).union(visibleIDs ?? []).union(pendingIDs)
            preRefreshMaxID = preRefreshIDs.max() ?? .max
            if isEnabled {
                if recaptureVisible || visibleIDs == nil {
                    visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
                }
            } else {
                visibleIDs = nil
            }
        }
        activeRefreshCount += 1
    }

    /// Diffs against `preRefreshIDs` on every call so an imbalanced count
    /// can't strand new arrivals outside `pendingIDs`.
    mutating func endRefresh(from articles: [Article], isEnabled: Bool) {
        guard activeRefreshCount > 0 else { return }
        activeRefreshCount -= 1
        let currentIDs = Set(articles.map(\.id))
        let newIDs = currentIDs.subtracting(preRefreshIDs)
        if !newIDs.isEmpty {
            pendingIDs.formUnion(newIDs)
        }
        if activeRefreshCount == 0 {
            preRefreshIDs = []
            preRefreshMaxID = .max
            preRefreshSnapshot = []
        }
    }

    /// Releases any pending articles into the visible list.
    mutating func acceptPendingRefresh() {
        guard !pendingIDs.isEmpty else { return }
        if visibleIDs != nil {
            visibleIDs = (visibleIDs ?? []).union(pendingIDs)
        }
        pendingIDs = []
    }
}
