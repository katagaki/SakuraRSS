@preconcurrency import BackgroundTasks
import UIKit
import WidgetKit
import Hanami

extension SakuraRSSApp {

    /// iOS keeps only one pending `BGAppRefreshTaskRequest` per app, so a single
    /// task refreshes every kind of feed, stalest first.
    nonisolated static let appRefreshTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"

    /// Per-category identifiers from earlier versions. Requests submitted with
    /// them can still launch the app, and a launch with no handler is a crash.
    nonisolated private static let legacyAppRefreshTaskIDs = [
        "rss", "reddit", "youtube", "rssSocial", "x", "instagram"
    ].map { "com.tsubuzaki.SakuraRSS.RefreshFeeds.\($0)" }

    /// Requests time out after 60s, so one slow feed would otherwise hold the
    /// task until the system expires it. Feeds cut off here count as attempted,
    /// so they don't trigger a continuation run.
    nonisolated private static let appRefreshHardLimit: Duration = .seconds(25)

    nonisolated func registerAppRefreshHandlers() {
        for identifier in [Self.appRefreshTaskID] + Self.legacyAppRefreshTaskIDs {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
                guard let task = task as? BGAppRefreshTask else { return }
                self.handleAppRefresh(task: task)
            }
        }
    }

    /// With `continuingSoon`, the next run is requested right away to pick up the
    /// feeds this one ran out of time for; otherwise it waits for the interval.
    /// The system still decides when the task actually runs.
    nonisolated func scheduleAppRefresh(continuingSoon: Bool = false) {
        for identifier in Self.legacyAppRefreshTaskIDs {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        }
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.appRefreshTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskID)
        if !continuingSoon {
            let refreshInterval = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
            let minutes = refreshInterval > 0 ? refreshInterval : 240
            request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        }
        do {
            try BGTaskScheduler.shared.submit(request)
            // swiftlint:disable:next line_length
            log("BackgroundRefresh", "submit success continuingSoon=\(continuingSoon) scheduledAt=\(request.earliestBeginDate?.description ?? "now")")
        } catch {
            log("BackgroundRefresh", "submit failed error=\(Self.describe(error))")
        }
    }

    nonisolated func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        log("BackgroundRefresh", "handleAppRefresh begin")

        let completion = BackgroundTaskCompletion(task: task)

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            log("BackgroundRefresh", "skipping: Low Power Mode is on")
            completion.complete(success: true)
            return
        }

        let refreshTask = Task { () -> Int in
            let options = await Self.backgroundImageOptions()
            let manager = await MainActor.run { FeedManager.forBackgroundRefresh() }
            let latestArticleIDBefore = DatabaseManager.shared.latestArticleID()
            let deferredCount = await Self.refreshFeedsWithinHardLimit(manager, options: options)
            if Task.isCancelled { return deferredCount }
            await MainActor.run { manager.reloadUnreadCounts() }
            manager.updateBadgeCount()
            if DatabaseManager.shared.latestArticleID() != latestArticleIDBefore {
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                log("BackgroundRefresh", "no new articles, skipping widget reload")
            }
            return deferredCount
        }

        task.expirationHandler = {
            log("BackgroundRefresh", "handleAppRefresh expired")
            refreshTask.cancel()
            self.scheduleAppRefresh(continuingSoon: true)
            completion.complete(success: false)
        }

        Task {
            let deferredCount = await refreshTask.value
            let wasExpired = refreshTask.isCancelled
            log("BackgroundRefresh", "handleAppRefresh end deferred=\(deferredCount) expired=\(wasExpired)")
            if deferredCount > 0, !wasExpired {
                scheduleAppRefresh(continuingSoon: true)
            }
            completion.complete(success: !wasExpired)
        }
    }

    nonisolated private static func refreshFeedsWithinHardLimit(
        _ manager: FeedManager,
        options: (skipImageFetch: Bool, skipImagePreload: Bool)
    ) async -> Int {
        let fetching = Task {
            await manager.refreshFeedsInBackground(
                skipImageFetch: options.skipImageFetch,
                skipImagePreload: options.skipImagePreload
            )
        }
        let watchdog = Task {
            try? await Task.sleep(for: appRefreshHardLimit)
            guard !Task.isCancelled else { return }
            log("BackgroundRefresh", "handleAppRefresh hit time limit")
            fetching.cancel()
        }
        let deferredCount = await withTaskCancellationHandler {
            await fetching.value
        } onCancel: {
            fetching.cancel()
        }
        watchdog.cancel()
        return deferredCount
    }

    nonisolated private static func backgroundImageOptions() async -> (skipImageFetch: Bool, skipImagePreload: Bool) {
        let pathExpensive = await NetworkMonitor.currentPathIsExpensive() ?? true
        // Gate image preload on plugged-in + Wi-Fi so it only runs during overnight charging.
        let pluggedIn = await deviceIsPluggedIn()
        return (resolveSkipImageFetch(pathExpensive: pathExpensive), pathExpensive || !pluggedIn)
    }

    nonisolated private static func resolveSkipImageFetch(pathExpensive: Bool) -> Bool {
        // nil probe means "assume expensive" so we default to the safer behavior.
        let imageFetchModeRaw = UserDefaults.standard.string(
            forKey: "BackgroundRefresh.ImageFetchMode"
        )
        let imageFetchMode = imageFetchModeRaw
            .flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
        switch imageFetchMode {
        case .always: return false
        case .wifiOnly: return pathExpensive
        case .off: return true
        }
    }

    nonisolated private static func deviceIsPluggedIn() async -> Bool {
        await MainActor.run { () -> Bool in
            let device = UIDevice.current
            let wasMonitoring = device.isBatteryMonitoringEnabled
            device.isBatteryMonitoringEnabled = true
            defer { device.isBatteryMonitoringEnabled = wasMonitoring }
            switch device.batteryState {
            case .charging, .full: return true
            case .unplugged, .unknown: return false
            @unknown default: return false
            }
        }
    }
}
