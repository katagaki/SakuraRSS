import SwiftUI
import Hanami

extension TodayView {

    // MARK: - Refresh

    var scopedRefreshState: ScopedRefreshState {
        feedManager.scopedRefreshes["section.today"] ?? ScopedRefreshState()
    }

    func startRefreshWithoutBlocking() {
        guard !scopedRefreshState.hasActiveProgress,
              !feedManager.hasActiveRefreshProgress else { return }
        feedManager.flushDebouncedReads()
        let feeds = feedManager.feeds
        let loadEntities = contentInsightsEnabled
        Task { @MainActor in
            await feedManager.refreshFeeds(scope: "section.today", feeds: feeds, runNLP: loadEntities)
            todayManager.load(
                feeds: feedManager.feeds,
                dataRevision: feedManager.dataRevision,
                loadEntities: loadEntities
            )
            summaryRefreshTrigger += 1
        }
    }

    // MARK: - Summary Visibility

    var anySummaryVisible: Bool {
        sleptVisible || afternoonVisible || todayVisible
    }

    /// Whether any summary card could appear right now, computed without the
    /// cards' own view state so the section mounts (and starts generating)
    /// independently of its own visibility. Cached in state because each
    /// check queries a full day of articles; recomputed per data revision
    /// rather than per body evaluation.
    func updateAnySummaryActive() {
        anySummaryActive = SummaryCardKind.whileYouSlept.couldDisplay(in: feedManager)
            || SummaryCardKind.afternoonBrief.couldDisplay(in: feedManager)
            || SummaryCardKind.todaysSummary.couldDisplay(in: feedManager)
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
