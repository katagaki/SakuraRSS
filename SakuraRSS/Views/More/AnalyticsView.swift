import SwiftUI

struct AnalyticsView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var totalRead: Int = 0
    @State private var streak: Int = 0
    @State private var mostReadFeedName: String?
    @State private var feedCount: Int = 0

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            StatCell(
                value: totalRead.formatted(),
                label: "Analytics.ArticlesRead",
                icon: "book.closed.fill"
            )
            StatCell(
                value: streak > 0 ? streak.formatted() : "-",
                label: "Analytics.Streak",
                icon: "flame.fill"
            )
            StatCell(
                value: feedCount.formatted(),
                label: "Analytics.FeedCount",
                icon: "list.bullet"
            )
            StatCell(
                value: mostReadFeedName ?? "-",
                label: "Analytics.MostViewed",
                icon: "star.fill",
                isText: mostReadFeedName != nil
            )
        }
        .task {
            await loadStats()
        }
    }

    private func loadStats() async {
        let db = DatabaseManager.shared
        let manager = feedManager
        await Task.detached {
            let read = (try? db.totalArticlesRead()) ?? 0
            let streakDays = (try? db.readingStreak()) ?? 0
            let feeds = (try? db.totalFeedCount()) ?? 0
            let topFeedID = try? db.mostReadFeedID()
            let topFeedName = topFeedID.flatMap { manager.feedsByID[$0]?.title }

            await MainActor.run {
                totalRead = read
                streak = streakDays
                feedCount = feeds
                mostReadFeedName = topFeedName
            }
        }.value
    }
}

private struct StatCell: View {

    let value: String
    let label: LocalizedStringKey
    let icon: String
    var isText: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isText {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            } else {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 60, alignment: .topLeading)
    }
}
