@preconcurrency import BackgroundTasks
import UIKit

extension SakuraRSSApp {

    func registerBackgroundTask() {
        registerLaunchHandlers(
            appRefreshTaskID: backgroundTaskID,
            cloudBackupTaskID: iCloudBackupTaskID
        )
        scheduleAppRefresh()
        scheduleiCloudBackup()
    }

    nonisolated private func registerLaunchHandlers(
        appRefreshTaskID: String,
        cloudBackupTaskID: String
    ) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: cloudBackupTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleiCloudBackup(task: task)
        }
    }

    nonisolated func scheduleAppRefresh() {
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        let refreshInterval = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
        let minutes = refreshInterval > 0 ? refreshInterval : 240
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        try? BGTaskScheduler.shared.submit(request)
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

        let refreshTask = Task {
            // nil probe means "assume expensive" so we default to the safer behavior.
            let imageFetchModeRaw = UserDefaults.standard.string(
                forKey: "BackgroundRefresh.ImageFetchMode"
            )
            let imageFetchMode = imageFetchModeRaw
                .flatMap(FetchImagesMode.init(rawValue:)) ?? .wifiOnly
            let pathExpensive = await NetworkMonitor.currentPathIsExpensive() ?? true
            let skipImageFetch: Bool = {
                switch imageFetchMode {
                case .always: return false
                case .wifiOnly: return pathExpensive
                case .off: return true
                }
            }()
            // Gate image preload on plugged-in + Wi-Fi so it only runs during overnight charging.
            let pluggedIn = await MainActor.run { () -> Bool in
                UIDevice.current.isBatteryMonitoringEnabled = true
                switch UIDevice.current.batteryState {
                case .charging, .full: return true
                case .unplugged, .unknown: return false
                @unknown default: return false
                }
            }
            let skipImagePreload = pathExpensive || !pluggedIn

            let manager = await MainActor.run { FeedManager() }
            // BGAppRefreshTask gets a ~30s budget; defer NLP to the foreground
            // pass so heavy work doesn't trip the watchdog mid-refresh.
            await manager.refreshAllFeeds(
                skipAuthenticatedFetchers: true,
                respectCooldown: true,
                skipImageFetch: skipImageFetch,
                skipImagePreload: skipImagePreload,
                runNLPAfter: false
            )
            if Task.isCancelled { return }
            manager.updateBadgeCount()
        }

        task.expirationHandler = {
            log("BackgroundRefresh", "handleAppRefresh expired")
            refreshTask.cancel()
            completion.complete(success: false)
        }

        Task {
            _ = await refreshTask.value
            log("BackgroundRefresh", "handleAppRefresh end cancelled=\(refreshTask.isCancelled)")
            completion.complete(success: !refreshTask.isCancelled)
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
        try? BGTaskScheduler.shared.submit(request)
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
}

/// Ensures `BGTask.setTaskCompleted(success:)` runs exactly once across the
/// completion path and the system's expiration handler. Without this, the
/// expiration handler can race with the trailing await, leading to a missed
/// or duplicated completion call and a watchdog termination.
final class BackgroundTaskCompletion: @unchecked Sendable {
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
