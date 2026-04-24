import SwiftUI

/// Tracks which article IDs are visible when Hide Viewed Content is on.
/// The snapshot is captured on first load and on refresh, extended on pagination,
/// and preserved across read-state changes so read articles remain visible until
/// the next explicit refresh.
struct ArticleVisibilityTracker {
    var visibleIDs: Set<Int64>?

    func filter(_ articles: [Article], isEnabled: Bool) -> [Article] {
        guard isEnabled, let visibleIDs else { return articles }
        return articles.filter { visibleIDs.contains($0.id) }
    }

    mutating func capture(from articles: [Article], isEnabled: Bool) {
        guard isEnabled else {
            visibleIDs = nil
            return
        }
        visibleIDs = Set(articles.filter { !$0.isRead }.map(\.id))
    }

    mutating func extend(from articles: [Article], isEnabled: Bool) {
        guard isEnabled else {
            visibleIDs = nil
            return
        }
        let unreadIDs = Set(articles.filter { !$0.isRead }.map(\.id))
        visibleIDs = (visibleIDs ?? []).union(unreadIDs)
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
            .onChange(of: loadedSinceDate) { _, _ in
                tracker.extend(from: rawArticles(), isEnabled: hideViewedContent)
            }
            .onChange(of: loadedCount) { _, _ in
                tracker.extend(from: rawArticles(), isEnabled: hideViewedContent)
            }
            .onChange(of: hideViewedContent) { _, newValue in
                if newValue {
                    tracker.capture(from: rawArticles(), isEnabled: newValue)
                } else {
                    tracker.visibleIDs = nil
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
