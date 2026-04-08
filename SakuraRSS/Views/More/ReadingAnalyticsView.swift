import SwiftUI

struct ReadingAnalyticsView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var totalRead: Int = 0
    @State private var streak: Int = 0
    @State private var mostReadFeedName: String?
    @State private var feedCount: Int = 0
    @State private var deadFeeds: Int = 0

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCell(
                value: "\(totalRead)",
                label: String(localized: "ReadingAnalytics.ArticlesRead"),
                icon: "book.closed"
            )
            StatCell(
                value: streak > 0 ? "\(streak)" : "—",
                label: String(localized: "ReadingAnalytics.Streak"),
                icon: "flame"
            )
            StatCell(
                value: "\(feedCount)",
                label: String(localized: "ReadingAnalytics.FeedCount"),
                icon: "list.bullet"
            )
            if let mostReadFeedName {
                StatCell(
                    value: mostReadFeedName,
                    label: String(localized: "ReadingAnalytics.MostRead"),
                    icon: "star",
                    isText: true
                )
            } else {
                StatCell(
                    value: "—",
                    label: String(localized: "ReadingAnalytics.MostRead"),
                    icon: "star"
                )
            }
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
            let threshold = Date().addingTimeInterval(-30 * 24 * 3600)
            let dead = (try? db.deadFeedCount(threshold: threshold)) ?? 0
            let topFeedID = try? db.mostReadFeedID()
            let topFeedName = topFeedID.flatMap { manager.feedsByID[$0]?.title }

            await MainActor.run {
                totalRead = read
                streak = streakDays
                feedCount = feeds
                deadFeeds = dead
                mostReadFeedName = topFeedName
            }
        }.value
    }
}

private struct StatCell: View {

    let value: String
    let label: String
    let icon: String
    var isText: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isText {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                } else {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
