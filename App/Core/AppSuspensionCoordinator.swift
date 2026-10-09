import UIKit
import Hanami

/// Holds the database gate open while the app is in the foreground and for the
/// background time UIKit grants after it leaves, so in-flight work can finish
/// before the gate closes and the process is suspended.
@MainActor
final class AppSuspensionCoordinator {

    static let shared = AppSuspensionCoordinator()

    private var holdsForegroundActivity = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    func appDidBecomeActive() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        holdForegroundActivity()
    }

    func appDidEnterBackground() {
        guard backgroundTaskID == .invalid else { return }
        holdForegroundActivity()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "DatabaseSuspension") {
            AppSuspensionCoordinator.shared.releaseForegroundActivity()
        }
        if backgroundTaskID == .invalid {
            releaseForegroundActivity()
        }
    }

    private func holdForegroundActivity() {
        guard !holdsForegroundActivity else { return }
        holdsForegroundActivity = true
        DatabaseSuspensionGate.shared.beginActivity()
    }

    private func releaseForegroundActivity() {
        let taskID = backgroundTaskID
        backgroundTaskID = .invalid
        guard holdsForegroundActivity else {
            if taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
            }
            return
        }
        holdsForegroundActivity = false
        Task.detached(priority: .userInitiated) {
            DatabaseSuspensionGate.shared.endActivity()
            LogManager.shared.flush()
            guard taskID != .invalid else { return }
            await MainActor.run {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }
}
