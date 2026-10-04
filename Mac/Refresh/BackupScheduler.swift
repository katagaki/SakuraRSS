import Foundation
import Hanami

/// Checks every few hours whether an iCloud backup is due, letting the system
/// choose the moment. Only on builds signed with iCloud.
final class BackupScheduler {

    private var scheduler: NSBackgroundActivityScheduler?

    func schedule() {
        scheduler?.invalidate()
        scheduler = nil
        let intervalRaw = UserDefaults.standard.integer(forKey: "iCloudBackup.Interval")
        let interval = iCloudBackupManager.BackupInterval(rawValue: intervalRaw) ?? .everyNight
        guard AppEntitlements.hasCloudKit, interval != .off else { return }
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.tsubuzaki.SakuraRSS.iCloudBackup")
        scheduler.repeats = true
        scheduler.interval = 3 * 60 * 60
        scheduler.qualityOfService = .background
        scheduler.schedule { completion in
            Task {
                await iCloudBackupManager.shared.backupIfScheduled()
                completion(.finished)
            }
        }
        self.scheduler = scheduler
    }
}
