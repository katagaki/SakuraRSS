@preconcurrency import BackgroundTasks
import Foundation

nonisolated enum AutomaticCleanupScheduler {

    static let taskIdentifier = "com.tsubuzaki.SakuraRSS.AutomaticCleanup"

    static func scheduleNextCleanup() {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "Cleanup.Automatic.Enabled")
        let cutoffRaw = defaults.string(forKey: "Cleanup.Automatic.Cutoff") ?? CleanupCutoff.last30Days.rawValue
        let cutoff = CleanupCutoff(rawValue: cutoffRaw) ?? .last30Days
        guard isEnabled, cutoff != .off else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func runCleanup(isCancelled: () -> Bool = { false }) async -> Bool {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.bool(forKey: "Cleanup.Automatic.Enabled")
        let cutoffRaw = defaults.string(forKey: "Cleanup.Automatic.Cutoff") ?? CleanupCutoff.last30Days.rawValue
        let cutoff = CleanupCutoff(rawValue: cutoffRaw) ?? .last30Days
        let includeBookmarks = defaults.bool(forKey: "Cleanup.Automatic.IncludeBookmarks")
        guard isEnabled, let cutoffDate = cutoff.cutoffDate() else {
            return true
        }
        guard !isCancelled() else { return false }
        let manager = await MainActor.run { FeedManager() }
        await manager.deleteArticlesAndVacuum(
            olderThan: cutoffDate,
            includeBookmarks: includeBookmarks
        )
        return !isCancelled()
    }
}
