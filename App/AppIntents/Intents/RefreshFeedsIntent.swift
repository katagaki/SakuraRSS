import AppIntents
import Foundation

struct RefreshFeedsIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("RefreshFeeds.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("RefreshFeeds.Description", table: "AppIntents")
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Refresh all feeds")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let database = DatabaseManager.shared
        let beforeFeeds = (try? database.allFeeds()) ?? []
        let beforeFetchTimes = Dictionary(uniqueKeysWithValues: beforeFeeds.map {
            ($0.id, $0.lastFetched ?? Date(timeIntervalSince1970: 0))
        })

        let manager = FeedManager()
        await manager.refreshAllFeeds()

        let afterFeeds = (try? database.allFeeds()) ?? []
        var refreshed = 0
        for feed in afterFeeds {
            let previous = beforeFetchTimes[feed.id] ?? Date(timeIntervalSince1970: 0)
            if let now = feed.lastFetched, now > previous {
                refreshed += 1
            }
        }
        return .result(value: refreshed)
    }
}
