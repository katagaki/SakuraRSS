import SwiftUI

extension AllArticlesView {

    var feedTabContent: some View {
        ArticlesView(
            articles: displayedArticles,
            title: HomeSection.all.localizedTitle,
            feedKey: "all",
            anySummaryHidden: anySummaryHidden,
            onRestoreSummaries: {
                withAnimation(.smooth.speed(2.0)) {
                    whileYouSleptDismissedDate = ""
                    todaysSummaryDismissedDate = ""
                }
            },
            onLoadMore: loadMoreAction,
            onRefresh: {
                await performRefresh()
            },
            onMarkAllRead: {
                feedManager.markAllRead()
            },
            scrollToTopTrigger: scrollToTopTick
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                WhileYouSleptView(
                    hasSummary: $whileYouSleptAvailable
                )
                TodaysSummaryView(
                    hasSummary: $todaysSummaryAvailable
                )
            }
            .animation(.smooth.speed(2.0), value: whileYouSleptDismissedDate)
            .animation(.smooth.speed(2.0), value: todaysSummaryDismissedDate)
            .padding(.bottom, 8)
        }
        .refreshable {
            log("AllArticlesView", ".refreshable triggered")
            startRefreshWithoutBlocking()
        }
        .trackArticleVisibility(
            $visibility,
            hideViewedContent: hideViewedContent,
            loadedSinceDate: loadedSinceDate,
            loadedCount: loadedCount,
            rawArticles: { rawArticles }
        )
        .trackBackgroundRefresh(
            $visibility,
            isLoading: feedManager.isLoading,
            hideViewedContent: hideViewedContent,
            rawArticles: { rawArticles }
        )
        .refreshPromptOverlay(isVisible: visibility.hasPendingRefresh) {
            acceptPendingRefresh()
        }
    }
}
