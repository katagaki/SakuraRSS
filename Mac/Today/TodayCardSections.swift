import Hanami
import SwiftUI

struct TodayCardSections: View {

    let model: TodayModel
    let feedManager: FeedManager
    let actions: TodayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !model.hasLoaded {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Today.Loading", table: "Home"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else if model.isEmpty {
                ContentUnavailableView(
                    String(localized: "Today.Empty.Title", table: "Home"),
                    systemImage: "checkmark.circle",
                    description: Text(String(localized: "Today.Empty.Description", table: "Home"))
                )
            } else {
                row("Today.ListenNow", table: "Home", articles: model.podcastEpisodes, usesSquareCards: true)
                row("Today.WatchNow", table: "Home", articles: model.videoEpisodes)
                row("Today.Bookmarks", table: "Home", articles: model.bookmarkedArticles)
                row("Discover.RecentlyAccessed", table: "Feeds", articles: model.recentArticles)
            }
        }
    }

    @ViewBuilder
    private func row(
        _ key: String.LocalizationValue,
        table: String,
        articles: [Article],
        usesSquareCards: Bool = false
    ) -> some View {
        if !articles.isEmpty {
            TodayCardRow(
                title: String(localized: key, table: table),
                articles: articles,
                feedManager: feedManager,
                actions: actions,
                usesSquareCards: usesSquareCards
            )
        }
    }
}
