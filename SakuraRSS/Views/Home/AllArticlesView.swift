import SwiftUI

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @State private var isShowingMarkAllReadConfirmation = false
    @State private var showingOlderArticles = false
    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @State private var whileYouSleptAvailable = false
    @State private var todaysSummaryAvailable = false

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var anySummaryHidden: Bool {
        (whileYouSleptDismissedDate == todayDateKey && whileYouSleptAvailable)
        || (todaysSummaryDismissedDate == todayDateKey && todaysSummaryAvailable)
    }

    private var displayedArticles: [Article] {
        if showingOlderArticles {
            return feedManager.todayArticles() + feedManager.olderArticles()
        } else {
            return feedManager.todayArticles()
        }
    }

    var body: some View {
        ArticleListView(
            articles: displayedArticles,
            title: String(localized: "Shared.AllArticles"),
            feedKey: "all",
            onLoadMore: showingOlderArticles ? nil : {
                showingOlderArticles = true
            }
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
        .toolbar {
            if anySummaryHidden {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            whileYouSleptDismissedDate = ""
                            todaysSummaryDismissedDate = ""
                        }
                    } label: {
                        Image(systemName: "apple.intelligence")
                    }
                }
            }
        }
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            FeedToolbar {
                feedManager.markAllRead()
            }
        }
    }
}
