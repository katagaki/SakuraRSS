import SwiftUI

/// Tracks which article IDs are visible when Hide Viewed Content is on.
/// The snapshot is captured on first load and on refresh, extended on pagination,
/// and preserved across read-state changes so read articles remain visible until
/// the next explicit refresh.
struct ArticleVisibilityTracker {
    var visibleIDs: Set<Int64>?
    /// True once a backwards pagination produced no new unread articles, so
    /// the load-more sentinel can be hidden until the next refresh / mode change.
    var hasReachedEnd: Bool = false

    func filter(_ articles: [Article], isEnabled: Bool) -> [Article] {
        guard isEnabled, let visibleIDs else { return articles }
        return articles.filter { visibleIDs.contains($0.id) }
    }

    mutating func capture(from articles: [Article], isEnabled: Bool) {
        hasReachedEnd = false
        guard isEnabled else {
            visibleIDs = nil
            return
        }
        visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
    }

    /// Returns true if at least one new unread ID was added.
    @discardableResult
    mutating func extend(from articles: [Article], isEnabled: Bool) -> Bool {
        guard isEnabled else {
            visibleIDs = nil
            return false
        }
        let unreadIDs = Set(articles.filter { !$0.isRead }.map(\.id))
        let previous = visibleIDs ?? []
        let merged = previous.union(unreadIDs)
        let didGrow = merged.count > previous.count
        visibleIDs = merged
        return didGrow
    }
}

private struct TrackArticleVisibilityModifier: ViewModifier {
    @Binding var tracker: ArticleVisibilityTracker
    let hideViewedContent: Bool
    let loadedSinceDate: Date
    let loadedCount: Int
    let rawArticles: () -> [Article]

    func body(content: Content) -> some View {
        content
            .task {
                if tracker.visibleIDs == nil {
                    tracker.capture(from: rawArticles(), isEnabled: hideViewedContent)
                }
            }
            .onChange(of: loadedSinceDate) { oldDate, newDate in
                let didGrow = tracker.extend(from: rawArticles(), isEnabled: hideViewedContent)
                if hideViewedContent, newDate < oldDate, !didGrow {
                    tracker.hasReachedEnd = true
                }
            }
            .onChange(of: loadedCount) { oldCount, newCount in
                let didGrow = tracker.extend(from: rawArticles(), isEnabled: hideViewedContent)
                if hideViewedContent, newCount > oldCount, !didGrow {
                    tracker.hasReachedEnd = true
                }
            }
            .onChange(of: hideViewedContent) { _, newValue in
                if newValue {
                    tracker.capture(from: rawArticles(), isEnabled: newValue)
                } else {
                    tracker.visibleIDs = nil
                    tracker.hasReachedEnd = false
                }
            }
    }
}

extension View {
    func trackArticleVisibility(
        _ tracker: Binding<ArticleVisibilityTracker>,
        hideViewedContent: Bool,
        loadedSinceDate: Date,
        loadedCount: Int,
        rawArticles: @escaping () -> [Article]
    ) -> some View {
        modifier(TrackArticleVisibilityModifier(
            tracker: tracker,
            hideViewedContent: hideViewedContent,
            loadedSinceDate: loadedSinceDate,
            loadedCount: loadedCount,
            rawArticles: rawArticles
        ))
    }
}
