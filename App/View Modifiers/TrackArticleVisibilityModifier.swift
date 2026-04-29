import SwiftUI

struct TrackArticleVisibilityModifier: ViewModifier {
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
