import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") var selectedSelection: HomeSelection = .section(.all)
    @AppStorage("Articles.BatchingMode") var storedBatchingMode: BatchingMode = .items25
    @AppStorage(DoomscrollingMode.storageKey) var doomscrollingMode: Bool = false
    @State var loadedSinceDate: Date = Date(timeIntervalSince1970: 0)
    @State var loadedCount: Int = BatchingMode.current().initialCount()
    @State var hasInitializedSinceDate = false
    @State var preloadedEntries: [ArticleIDEntry] = []
    @AppStorage("WhileYouSlept.DismissedDate") var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") var todaysSummaryDismissedDate: String = ""
    @AppStorage("Instagram.HideReels") var hideInstagramReels: Bool = false
    @AppStorage("Articles.HideViewedContent") var storedHideViewedContent: Bool = false
    @State var visibility = ArticleVisibilityTracker()
    @State var scrollToTopTick: Int = 0
    @State var whileYouSleptAvailable = false
    @State var todaysSummaryAvailable = false

    var body: some View {
        Group {
            switch selectedSelection {
            case .section(let section):
                if let feedSection = section.feedSection {
                    HomeSectionView(section: feedSection)
                } else {
                    feedTabContent
                }
            case .list(let id):
                if let list = feedManager.lists.first(where: { $0.id == id }) {
                    ListSectionView(list: list)
                } else {
                    feedTabContent
                }
            }
        }
        .navigationTitle(currentTitle)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarTitleMenu {
            titleMenuContent
        }
        .onChange(of: availableSections) {
            validateSelection()
        }
        .onChange(of: feedManager.lists) {
            validateSelection()
        }
        .onAppear {
            // swiftlint:disable:next line_length
            log("AllArticlesView", "onAppear selection=\(selectedSelection.rawValue) hasInitializedSinceDate=\(hasInitializedSinceDate)")
            reloadPreloadedEntries()
            if !hasInitializedSinceDate {
                loadedSinceDate = batchingMode.initialSinceDate(
                    latestArticleDate: latestArticleDateAcrossFeeds()
                )
                hasInitializedSinceDate = true
            }
        }
        .onChange(of: feedManager.dataRevision) { _, _ in
            reloadPreloadedEntries()
        }
        .onChange(of: hideViewedContent) { _, _ in
            reloadPreloadedEntries()
            loadedSinceDate = batchingMode.initialSinceDate(
                latestArticleDate: latestArticleDateAcrossFeeds()
            )
            loadedCount = batchingMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: batchingMode) { _, newMode in
            loadedSinceDate = newMode.initialSinceDate(
                latestArticleDate: latestArticleDateAcrossFeeds()
            )
            loadedCount = newMode.initialCount()
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
        .onChange(of: doomscrollingMode) { _, _ in
            visibility.capture(from: rawArticles, isEnabled: hideViewedContent)
        }
    }
}
