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

    /// Also called on `willEnterForeground`, since foreground loads start before
    /// the app becomes active and the gate may still be closed from the last suspension.
    func appDidEnterForeground() {
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
        let drained = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            DatabaseSuspensionGate.shared.endActivity()
            LogManager.shared.flush()
            drained.signal()
        }
        guard taskID != .invalid else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            _ = drained.wait(timeout: .now() + Self.drainTimeout)
            DispatchQueue.main.async {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }

    /// The system kills the app if it doesn't end the task shortly after expiry.
    nonisolated private static let drainTimeout: TimeInterval = 2
}
