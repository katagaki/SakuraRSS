import Foundation

/// The settings the background schedules read, compared so a schedule is only
/// rebuilt when one of them changes, not on every unrelated defaults write.
struct SchedulingSettings: Equatable {

    let isPeriodicRefreshEnabled: Bool
    let refreshInterval: Int
    let isAutomaticCleanupEnabled: Bool
    let cleanupCutoff: String?
    let backupInterval: Int

    static var current: SchedulingSettings {
        let defaults = UserDefaults.standard
        return SchedulingSettings(
            isPeriodicRefreshEnabled: defaults.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true,
            refreshInterval: defaults.integer(forKey: "BackgroundRefresh.Interval"),
            isAutomaticCleanupEnabled: defaults.bool(forKey: "Cleanup.Automatic.Enabled"),
            cleanupCutoff: defaults.string(forKey: "Cleanup.Automatic.Cutoff"),
            backupInterval: defaults.integer(forKey: "iCloudBackup.Interval")
        )
    }
}
