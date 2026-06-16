@preconcurrency import BackgroundTasks
import UIKit
import Hanami

extension SakuraRSSApp {

    func registerBackgroundTask() {
        registerLaunchHandlers(cloudBackupTaskID: iCloudBackupTaskID)
        scheduleAppRefresh()
        scheduleiCloudBackup()
        AutomaticCleanupScheduler.scheduleNextCleanup()
        NighttimeBackfillScheduler.scheduleAll()
    }

    nonisolated private func registerLaunchHandlers(cloudBackupTaskID: String) {
        for category in BackgroundRefreshCategory.allCases {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: category.taskID,
                using: nil
            ) { task in
                guard let task = task as? BGAppRefreshTask else { return }
                self.handleAppRefresh(category: category, task: task)
            }
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: cloudBackupTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleiCloudBackup(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AutomaticCleanupScheduler.taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleAutomaticCleanup(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: NighttimeBackfillScheduler.nlpTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleNLPBackfill(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: NighttimeBackfillScheduler.imageTaskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleImageBackfill(task: task)
        }
    }

    /// Submits a `BGAppRefreshTaskRequest` per category so each one gets its
    /// own ~30s budget. All categories share the same user-configured interval.
    nonisolated func scheduleAppRefresh() {
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else {
            for category in BackgroundRefreshCategory.allCases {
                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: category.taskID)
            }
            return
        }
        let refreshInterval = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
        let minutes = refreshInterval > 0 ? refreshInterval : 240
        let base = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        for (index, category) in BackgroundRefreshCategory.allCases.enumerated() {
            let earliest = base.addingTimeInterval(TimeInterval(index * 2 * 60))
            let request = BGAppRefreshTaskRequest(identifier: category.taskID)
            request.earliestBeginDate = earliest
            do {
                try BGTaskScheduler.shared.submit(request)
                log("BackgroundRefresh", "submit success category=\(category.rawValue) scheduledAt=\(earliest)")
            } catch {
                log("BackgroundRefresh", "submit failed category=\(category.rawValue) error=\(Self.describe(error))")
            }
        }
    }

    nonisolated func handleAppRefresh(
        category: BackgroundRefreshCategory,
        task: BGAppRefreshTask
    ) {
        scheduleAppRefresh()
        log("BackgroundRefresh", "handleAppRefresh begin category=\(category.rawValue)")

        let completion = BackgroundTaskCompletion(task: task)

        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            log("BackgroundRefresh", "skipping category=\(category.rawValue): Low Power Mode is on")
            completion.complete(success: true)
            return
        }

        let refreshTask = Task {
            let pathExpensive = await NetworkMonitor.currentPathIsExpensive() ?? true
            let skipImageFetch = Self.resolveSkipImageFetch(pathExpensive: pathExpensive)
            // Gate image preload on plugged-in + Wi-Fi so it only runs during overnight charging.
            let pluggedIn = await Self.deviceIsPluggedIn()
            let skipImagePreload = pathExpensive || !pluggedIn

            let manager = await MainActor.run { FeedManager() }
            await manager.refreshFeeds(
                in: category,
                skipImageFetch: skipImageFetch,
                skipImagePreload: skipImagePreload
            )
            if Task.isCancelled { return }
            manager.updateBadgeCount()
        }

        task.expirationHandler = {
            log("BackgroundRefresh", "handleAppRefresh expired category=\(category.rawValue)")
            refreshTask.cancel()
            completion.complete(success: false)
        }

        Task {
            _ = await refreshTask.value
            log(
                "BackgroundRefresh",
                "handleAppRefresh end category=\(category.rawValue) cancelled=\(refreshTask.isCancelled)"
            )
            completion.complete(success: !refreshTask.isCancelled)
        }
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

    nonisolated static func describe(_ error: Error) -> String {
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

    nonisolated private static func deviceIsPluggedIn() async -> Bool {
        await MainActor.run { () -> Bool in
            UIDevice.current.isBatteryMonitoringEnabled = true
            switch UIDevice.current.batteryState {
            case .charging, .full: return true
            case .unplugged, .unknown: return false
            @unknown default: return false
            }
        }
    }

    /// Submits a `BGProcessingTaskRequest` for the iCloud backup; requires
    /// network + external power so it runs overnight on Wi-Fi.
    nonisolated func scheduleiCloudBackup() {
        let intervalRaw = UserDefaults.standard.integer(forKey: "iCloudBackup.Interval")
        let interval = iCloudBackupManager.BackupInterval(rawValue: intervalRaw) ?? .everyNight
        guard interval != .off else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: iCloudBackupTaskID)
            return
        }
        let request = BGProcessingTaskRequest(identifier: iCloudBackupTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = earliestBackupDate(for: interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log("iCloudBackup", "submit failed error=\(Self.describe(error))")
        }
    }

    nonisolated private func earliestBackupDate(for interval: iCloudBackupManager.BackupInterval) -> Date {
        // For `.everyNight`, target the next 2 AM local so the run overlaps with typical overnight charging.
        switch interval {
        case .everyNight:
            let calendar = Calendar.current
            let now = Date()
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = 2
            components.minute = 0
            components.second = 0
            let candidate = calendar.date(from: components) ?? now
            if candidate > now {
                return candidate
            }
            return calendar.date(byAdding: .day, value: 1, to: candidate) ?? now.addingTimeInterval(86400)
        case .every12Hours, .every6Hours, .off:
            return Date(timeIntervalSinceNow: TimeInterval(interval.rawValue))
        }
    }

    nonisolated func handleiCloudBackup(task: BGProcessingTask) {
        scheduleiCloudBackup()

        let completion = BackgroundTaskCompletion(task: task)

        let backupTask = Task {
            await iCloudBackupManager.shared.backupIfScheduled()
        }

        task.expirationHandler = {
            backupTask.cancel()
            completion.complete(success: false)
        }

        Task {
            _ = await backupTask.value
            completion.complete(success: !backupTask.isCancelled)
        }
    }

    nonisolated func handleAutomaticCleanup(task: BGProcessingTask) {
        AutomaticCleanupScheduler.scheduleNextCleanup()
        log("AutomaticCleanup", "handleAutomaticCleanup begin")

        let completion = BackgroundTaskCompletion(task: task)

        let cleanupTask = Task {
            await AutomaticCleanupScheduler.runCleanup(isCancelled: { Task.isCancelled })
        }

        task.expirationHandler = {
            log("AutomaticCleanup", "handleAutomaticCleanup expired")
            cleanupTask.cancel()
            completion.complete(success: false)
        }

        Task {
            let success = await cleanupTask.value
            log("AutomaticCleanup", "handleAutomaticCleanup end success=\(success)")
            completion.complete(success: success)
        }
    }

    nonisolated func handleNLPBackfill(task: BGProcessingTask) {
        NighttimeBackfillScheduler.scheduleNLPBackfill()
        log("NighttimeBackfill", "handleNLPBackfill begin")

        let completion = BackgroundTaskCompletion(task: task)

        let work = Task {
            await NighttimeBackfillScheduler.runNLPBackfill()
        }

        task.expirationHandler = {
            log("NighttimeBackfill", "handleNLPBackfill expired")
            work.cancel()
            completion.complete(success: false)
        }

        Task {
            _ = await work.value
            log("NighttimeBackfill", "handleNLPBackfill end cancelled=\(work.isCancelled)")
            completion.complete(success: !work.isCancelled)
        }
    }

    nonisolated func handleImageBackfill(task: BGProcessingTask) {
        NighttimeBackfillScheduler.scheduleImageBackfill()
        log("NighttimeBackfill", "handleImageBackfill begin")

        let completion = BackgroundTaskCompletion(task: task)

        let work = Task {
            await NighttimeBackfillScheduler.runImageBackfill()
        }

        task.expirationHandler = {
            log("NighttimeBackfill", "handleImageBackfill expired")
            work.cancel()
            completion.complete(success: false)
        }

        Task {
            _ = await work.value
            log("NighttimeBackfill", "handleImageBackfill end cancelled=\(work.isCancelled)")
            completion.complete(success: !work.isCancelled)
        }
    }
}

nonisolated final class BackgroundTaskCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private let task: BGTask

    init(task: BGTask) {
        self.task = task
    }

    func complete(success: Bool) {
        lock.lock()
        if didComplete {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()
        task.setTaskCompleted(success: success)
    }
}
