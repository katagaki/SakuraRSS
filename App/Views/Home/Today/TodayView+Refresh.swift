import SwiftUI

extension TodayView {

    // MARK: - Refresh

    var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes["section.all"] ?? ScopedRefreshState()
    }

    func startRefreshWithoutBlocking() {
        guard !scopedRefreshState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        summaryRefreshTrigger += 1
        let feeds = feedManager.feeds
        let loadEntities = contentInsightsEnabled
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: "section.all", feeds: feeds)
            todayManager.load(
                feeds: feedManager.feeds,
                dataRevision: feedManager.dataRevision,
                loadEntities: loadEntities
            )
        }
    }

    // MARK: - Data

    var filteredTopics: [(name: String, count: Int)] {
        let topics = todayManager.allTopics.filter { $0.count > 1 }
        let peopleCount = todayManager.allPeople.filter { $0.count > 1 }.count
        let topicCap = max(0, min(topics.count, 20 - min(peopleCount, 10)))
        return Array(topics.prefix(topicCap))
    }

    var filteredPeople: [(name: String, count: Int)] {
        let people = todayManager.allPeople.filter { $0.count > 1 }
        let remaining = max(0, 20 - filteredTopics.count)
        return Array(people.prefix(remaining))
    }
}
