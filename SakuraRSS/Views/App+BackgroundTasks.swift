import BackgroundTasks
import UIKit

extension SakuraRSSApp {

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: iCloudBackupTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            self.handleiCloudBackup(task: task)
        }
        scheduleAppRefresh()
        scheduleiCloudBackup()
    }

    func scheduleAppRefresh() {
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

    func handleAppRefresh(task: BGAppRefreshTask) {
        // Always reschedule the next window before deciding what to run.
        scheduleAppRefresh()

        // Respect Low Power Mode: do no background work at all, just
        // complete cleanly so the system doesn't count this as a failure.
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            task.setTaskCompleted(success: true)
            return
        }

        let refreshTask = Task {
            // Skip per-article HTML metadata image backfill when we're on
            // an expensive path (cellular / hotspot) and the user has the
            // Wi-Fi-only preference on.  The feed bodies themselves still
            // load; only the optional og:image lookup is deferred.  A nil
            // probe result is treated as "assume expensive" so we default
            // to the safer behavior when the network type is unknown.
            let wifiOnly = UserDefaults.standard.object(
                forKey: "BackgroundRefresh.ImageBackfillWiFiOnly"
            ) as? Bool ?? true
            let pathExpensive = await NetworkMonitor.currentPathIsExpensive() ?? true
            let skipImageBackfill = wifiOnly && pathExpensive
            // Per-article image preload is an order of magnitude more
            // bandwidth than the og:image lookup, and background fetches
            // run off the user's battery.  Gate on plugged-in + Wi-Fi so
            // it only ever runs during an overnight/desk charging window.
            let pluggedIn = await MainActor.run { () -> Bool in
                UIDevice.current.isBatteryMonitoringEnabled = true
                switch UIDevice.current.batteryState {
                case .charging, .full: return true
                case .unplugged, .unknown: return false
                @unknown default: return false
                }
            }
            let skipImagePreload = pathExpensive || !pluggedIn

            let manager = FeedManager()
            await manager.refreshAllFeeds(
                skipAuthenticatedScrapers: true,
                respectCooldown: true,
                skipImageBackfill: skipImageBackfill,
                skipImagePreload: skipImagePreload,
                runNLPAfter: true
            )
            manager.updateBadgeCount()
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }

        Task {
            _ = await refreshTask.value
            task.setTaskCompleted(success: true)
        }
    }

    /// Submits a `BGProcessingTaskRequest` for the iCloud backup, requiring
    /// network connectivity and external power so the system runs it during
    /// idle/charging windows (typically overnight on Wi-Fi). Cancelled if the
    /// user has set the backup interval to Off.
    func scheduleiCloudBackup() {
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

    /// For `.everyNight`, target the next occurrence of 2 AM local time so
    /// the task's earliest run overlaps with typical overnight charging.
    /// Using `now + 24h` caused the window to drift forward each launch,
    /// landing mid-day when the device is rarely plugged in.
    private func earliestBackupDate(for interval: iCloudBackupManager.BackupInterval) -> Date {
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

    func handleiCloudBackup(task: BGProcessingTask) {
        // Always reschedule the next window before doing any work.
        scheduleiCloudBackup()

        let backupTask = Task {
            await iCloudBackupManager.shared.backupIfScheduled()
        }

        task.expirationHandler = {
            backupTask.cancel()
        }

        Task {
            _ = await backupTask.value
            task.setTaskCompleted(success: true)
        }
    }
}
