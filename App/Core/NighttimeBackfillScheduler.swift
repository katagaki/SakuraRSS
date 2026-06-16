@preconcurrency import BackgroundTasks
import Foundation
import Hanami

/// Schedules best-effort overnight `BGProcessingTask`s that backfill NLP
/// (3 AM) and article images (4 AM). Both require the device to be charging.
nonisolated enum NighttimeBackfillScheduler {

    static let nlpTaskIdentifier = "com.tsubuzaki.SakuraRSS.NLPBackfill"
    static let imageTaskIdentifier = "com.tsubuzaki.SakuraRSS.ImageBackfill"

    private static let nlpHour = 3
    private static let imageHour = 4

    static func scheduleAll() {
        scheduleNLPBackfill()
        scheduleImageBackfill()
    }

    static func scheduleNLPBackfill() {
        submit(identifier: nlpTaskIdentifier, hour: nlpHour, requiresNetwork: false)
    }

    static func scheduleImageBackfill() {
        submit(identifier: imageTaskIdentifier, hour: imageHour, requiresNetwork: true)
    }

    private static func submit(identifier: String, hour: Int, requiresNetwork: Bool) {
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = requiresNetwork
        request.earliestBeginDate = nextDate(atHour: hour)
        do {
            try BGTaskScheduler.shared.submit(request)
            // swiftlint:disable:next line_length
            log("NighttimeBackfill", "submit success id=\(identifier) at=\(request.earliestBeginDate?.description ?? "?")")
        } catch {
            log("NighttimeBackfill", "submit failed id=\(identifier) error=\(describe(error))")
        }
    }

    static func runNLPBackfill() async {
        await NLPProcessingCoordinator.processNewArticlesIfEnabled()
    }

    static func runImageBackfill() async {
        let modeRaw = UserDefaults.standard.string(forKey: "FeedRefresh.PreloadArticleImagesMode")
        let mode = modeRaw.flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
        switch mode {
        case .off:
            log("NighttimeBackfill", "image backfill skipped: preload disabled")
            return
        case .wifiOnly:
            if await NetworkMonitor.currentPathIsExpensive() ?? true {
                log("NighttimeBackfill", "image backfill skipped: expensive network path")
                return
            }
        case .always:
            break
        }
        await FeedManager.backfillRecentImages()
    }

    private static func nextDate(atHour hour: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        components.second = 0
        let candidate = calendar.date(from: components) ?? now
        if candidate > now {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(86400)
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
