@preconcurrency import BackgroundTasks
import Foundation
import Hanami

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
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log("AutomaticCleanup", "submit failed error=\(describe(error))")
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == BGTaskScheduler.errorDomain,
           let code = BGTaskScheduler.Error.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable: return "unavailable (Background App Refresh disabled in Settings; common on Simulator)"
            case .tooManyPendingTaskRequests: return "tooManyPendingTaskRequests"
            case .notPermitted: return "notPermitted (identifier missing from Info.plist?)"
            @unknown default: return "unknownBGCode(\(nsError.code))"
            }
        }
        return "\(nsError.domain):\(nsError.code) \(nsError.localizedDescription)"
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
