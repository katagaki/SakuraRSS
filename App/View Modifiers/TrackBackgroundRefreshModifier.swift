import SwiftUI

struct TrackBackgroundRefreshModifier: ViewModifier {
    @Binding var tracker: ArticleVisibilityTracker
    let isLoading: Bool
    let hideViewedContent: Bool
    let rawArticles: () -> [Article]

    func body(content: Content) -> some View {
        content
            .task {
                if isLoading {
                    tracker.beginRefresh(from: rawArticles(), isEnabled: hideViewedContent)
                }
            }
            .onChange(of: isLoading) { _, newValue in
                if newValue {
                    tracker.beginRefresh(from: rawArticles(), isEnabled: hideViewedContent)
                } else {
                    withAnimation(.smooth.speed(2.0)) {
                        tracker.endRefresh(from: rawArticles(), isEnabled: hideViewedContent)
                    }
                }
            }
    }
}

extension View {
    /// Observes a background refresh signal and snapshots / computes pending
    /// articles so the refresh prompt button can appear once new content arrives.
    func trackBackgroundRefresh(
        _ tracker: Binding<ArticleVisibilityTracker>,
        isLoading: Bool,
        hideViewedContent: Bool,
        rawArticles: @escaping () -> [Article]
    ) -> some View {
        modifier(TrackBackgroundRefreshModifier(
            tracker: tracker,
            isLoading: isLoading,
            hideViewedContent: hideViewedContent,
            rawArticles: rawArticles
        ))
    }
}
