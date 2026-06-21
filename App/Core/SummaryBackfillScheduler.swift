@preconcurrency import BackgroundTasks
import Foundation
import Hanami

/// Schedules a best-effort `BGProcessingTask` that pre-generates Apple
/// Intelligence summary headlines so the Home cards load from cache instead
/// of generating on launch. Submitted 30 minutes after a background feed
/// refresh finishes and only runs while the device is charging.
nonisolated enum SummaryBackfillScheduler {

    static let taskIdentifier = "com.tsubuzaki.SakuraRSS.SummaryBackfill"

    private static let postRefreshDelay: TimeInterval = 30 * 60

    static func schedule(after delay: TimeInterval = postRefreshDelay) {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: delay)
        do {
            try BGTaskScheduler.shared.submit(request)
            log("SummaryBackfill", "submit success at=\(request.earliestBeginDate?.description ?? "?")")
        } catch {
            log("SummaryBackfill", "submit failed error=\(describe(error))")
        }
    }

    @MainActor
    static func runBackfill(isCancelled: @Sendable () -> Bool = { false }) async {
        let date = Date()
        let manager = FeedManager()
        for kind in [SummaryCardKind.whileYouSlept, .afternoonBrief, .todaysSummary] {
            if isCancelled() { return }
            await generateIfNeeded(kind: kind, manager: manager, date: date)
        }
    }

    /// Generates and caches one summary kind, but only when it would actually
    /// be displayable right now and isn't already cached for today.
    @MainActor
    private static func generateIfNeeded(
        kind: SummaryCardKind,
        manager: FeedManager,
        date: Date
    ) async {
        guard kind.couldDisplay(in: manager) else {
            log("SummaryBackfill", "skip kind=\(kind): not displayable now")
            return
        }
        if let cached = try? DatabaseManager.shared.cachedSummaryHeadlines(
            ofType: kind.cacheType, for: date
        ), !cached.headlines.isEmpty {
            log("SummaryBackfill", "skip kind=\(kind): already cached")
            return
        }
        let generator = SummaryHeadlineGenerator(kind: kind, feedManager: manager)
        switch await generator.generate(for: date) {
        case .generated(let headlines, _, _):
            log("SummaryBackfill", "generated kind=\(kind) headlines=\(headlines.count)")
        case .noContent:
            log("SummaryBackfill", "no content kind=\(kind)")
        case .failed(let error):
            log("SummaryBackfill", "failed kind=\(kind) error=\(error?.localizedDescription ?? "nil")")
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == BGTaskScheduler.errorDomain,
           let code = BGTaskScheduler.Error.Code(rawValue: nsError.code) {
            switch code {
            case .unavailable: return "unavailable (Background App Refresh disabled)"
            case .tooManyPendingTaskRequests: return "tooManyPendingTaskRequests"
            case .notPermitted: return "notPermitted (identifier missing from Info.plist?)"
            case .immediateRunIneligible: return "immediateRunIneligible"
            @unknown default: return "unknownBGCode(\(nsError.code))"
            }
        }
        return "\(nsError.domain):\(nsError.code) \(nsError.localizedDescription)"
    }
}
