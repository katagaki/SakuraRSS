import SwiftUI

extension AllArticlesView {

    func performRefresh() async {
        log("AllArticlesView", "performRefresh isLoading=\(feedManager.isLoading)")
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        await feedManager.refreshAllFeeds()
        withAnimation(.smooth.speed(2.0)) {
            visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
        }
        log("AllArticlesView", "performRefresh end")
    }

    /// Kicks off a refresh and returns immediately so SwiftUI dismisses the
    /// pull-to-refresh indicator; in-flight progress shows via the toolbar donut.
    func startRefreshWithoutBlocking() {
        log("AllArticlesView", "startRefreshWithoutBlocking isLoading=\(feedManager.isLoading)")
        guard !feedManager.isLoading else { return }
        feedManager.flushDebouncedReads()
        withAnimation(.smooth.speed(2.0)) {
            visibility.beginRefresh(
                from: rawArticles,
                isEnabled: hideViewedContent,
                recaptureVisible: true
            )
        }
        Task { @MainActor in
            await feedManager.refreshAllFeeds()
            withAnimation(.smooth.speed(2.0)) {
                visibility.endRefresh(from: rawArticles, isEnabled: hideViewedContent)
            }
            log("AllArticlesView", "startRefreshWithoutBlocking end")
        }
    }

    func acceptPendingRefresh() {
        withAnimation(.smooth.speed(2.0)) {
            visibility.acceptPendingRefresh()
        }
        scrollToTopTick &+= 1
    }
}
