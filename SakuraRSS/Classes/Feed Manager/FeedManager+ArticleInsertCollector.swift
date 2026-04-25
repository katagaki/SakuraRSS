import Foundation

/// Accumulates parsed articles across a multi-feed refresh so they can be written
/// to the database in a single transaction at the end. This avoids per-feed inserts
/// causing the home article list to re-sort/jump around during eager reloads.
actor ArticleInsertCollector {

    struct Pending: Sendable {
        let feedID: Int64
        let items: [ArticleInsertItem]
        let feedTitleForSpotlight: String
    }

    private var pending: [Pending] = []

    func add(feedID: Int64, items: [ArticleInsertItem], feedTitleForSpotlight: String) {
        guard !items.isEmpty else { return }
        pending.append(Pending(
            feedID: feedID, items: items, feedTitleForSpotlight: feedTitleForSpotlight
        ))
    }

    func drain() -> [Pending] {
        let out = pending
        pending.removeAll(keepingCapacity: false)
        return out
    }

    var isEmpty: Bool { pending.isEmpty }
}
