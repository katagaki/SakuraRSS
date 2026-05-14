import SwiftUI
import Hanami

/// Tracks which article IDs are visible when Hide Viewed Content is on, and
/// holds back articles that arrive during a refresh until the user accepts
/// them via the refresh prompt button.
struct ArticleVisibilityTracker {

    var visibleIDs: Set<Int64>?
    var pendingIDs: Set<Int64> = []
    var hasReachedEnd: Bool = false

    private var preRefreshIDs: Set<Int64> = []
    private var preRefreshMaxID: Int64 = .max
    private var preRefreshSnapshot: [Article] = []
    private var activeRefreshCount: Int = 0

    var hasPendingRefresh: Bool { !pendingIDs.isEmpty }

    func filter(_ articles: [Article], isEnabled: Bool) -> [Article] {
        var result = articles
        if activeRefreshCount > 0 || !pendingIDs.isEmpty {
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
        guard !articles.isEmpty else { return }
        visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
    }

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

    mutating func beginRefresh(
        from articles: [Article],
        isEnabled: Bool,
        recaptureVisible: Bool = false
    ) {
        if activeRefreshCount == 0 {
            hasReachedEnd = false
            if pendingIDs.isEmpty {
                preRefreshSnapshot = articles
                preRefreshMaxID = Set(articles.map(\.id))
                    .union(visibleIDs ?? [])
                    .max() ?? .max
            }
            preRefreshIDs = Set(articles.map(\.id))
                .union(visibleIDs ?? [])
                .union(pendingIDs)
                .union(preRefreshSnapshot.map(\.id))
            if isEnabled {
                if (recaptureVisible || visibleIDs == nil) && !articles.isEmpty {
                    visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
                }
            } else {
                visibleIDs = nil
            }
        }
        activeRefreshCount += 1
    }

    mutating func endRefresh(from articles: [Article], isEnabled: Bool) {
        guard activeRefreshCount > 0 else { return }
        activeRefreshCount -= 1
        let currentIDs = Set(articles.map(\.id))
        let newIDs = currentIDs
            .subtracting(preRefreshIDs)
            .filter { $0 > preRefreshMaxID }
        let hadPriorContent = !preRefreshIDs.isEmpty || !pendingIDs.isEmpty
        if !newIDs.isEmpty, hadPriorContent {
            pendingIDs.formUnion(newIDs)
        }
        if activeRefreshCount == 0 {
            preRefreshIDs = []
            if pendingIDs.isEmpty {
                preRefreshMaxID = .max
                preRefreshSnapshot = []
            }
        }
    }

    mutating func acceptPendingRefresh() {
        guard !pendingIDs.isEmpty else { return }
        if visibleIDs != nil {
            visibleIDs = (visibleIDs ?? []).union(pendingIDs)
        }
        pendingIDs = []
        if activeRefreshCount == 0 {
            preRefreshMaxID = .max
            preRefreshSnapshot = []
        }
    }
}
