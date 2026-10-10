@preconcurrency import BackgroundTasks
import Hanami
import UIKit

/// Mirrors in-app refresh progress into a continued processing task, so the
/// system shows it like a download and the refresh keeps going after the app
/// is left.
@MainActor
final class RefreshProgressActivity {

    static let shared = RefreshProgressActivity()

    nonisolated private static let identifierPrefix = "com.tsubuzaki.SakuraRSS.ContinuedRefresh"

    private weak var feedManager: FeedManager?
    private var task: BGContinuedProcessingTask?
    private var completion: BackgroundTaskCompletion?
    private var requestedIdentifier: String?

    func start(observing feedManager: FeedManager) {
        guard self.feedManager == nil else { return }
        self.feedManager = feedManager
        observeProgress()
    }

    private func observeProgress() {
        guard let feedManager else { return }
        let progress = withObservationTracking {
            RefreshProgress(of: feedManager)
        } onChange: {
            Task { @MainActor in
                RefreshProgressActivity.shared.observeProgress()
            }
        }
        if progress.total > 0 {
            requestTaskIfNeeded(for: progress)
            report(progress)
        } else {
            finish(success: true)
        }
    }

    /// Submission only succeeds while the app is in the foreground, and `.fail`
    /// skips it when the system can't run it right away; the refresh runs either way.
    /// Info.plist permits the wildcard, but each concrete identifier needs its own handler.
    private func requestTaskIfNeeded(for progress: RefreshProgress) {
        guard requestedIdentifier == nil, UIApplication.shared.applicationState == .active else { return }
        let identifier = "\(Self.identifierPrefix).\(UUID().uuidString)"
        requestedIdentifier = identifier
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            MainActor.assumeIsolated {
                RefreshProgressActivity.shared.attach(task)
            }
        }
        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: Self.title,
            subtitle: Self.subtitle(for: progress)
        )
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log("RefreshProgressActivity", "submit failed error=\(SakuraRSSApp.describe(error))")
        }
    }

    private func attach(_ task: BGContinuedProcessingTask) {
        let progress = feedManager.map(RefreshProgress.init(of:)) ?? RefreshProgress()
        let completion = BackgroundTaskCompletion(task: task)
        guard progress.total > 0, self.task == nil, task.identifier == requestedIdentifier else {
            completion.complete(success: true)
            return
        }
        self.task = task
        self.completion = completion
        task.expirationHandler = {
            Task { @MainActor in
                RefreshProgressActivity.shared.expire()
            }
        }
        report(progress)
    }

    private func report(_ progress: RefreshProgress) {
        guard let task else { return }
        task.progress.totalUnitCount = Int64(progress.total)
        task.progress.completedUnitCount = Int64(min(progress.completed, progress.total))
        task.updateTitle(Self.title, subtitle: Self.subtitle(for: progress))
    }

    private func expire() {
        log("RefreshProgressActivity", "expired, stopping refreshes")
        if let feedManager {
            feedManager.cancelRefresh()
            for scope in feedManager.scopedRefreshes.keys {
                feedManager.cancelScopedRefresh(scope: scope)
            }
        }
        finish(success: false)
    }

    private func finish(success: Bool) {
        requestedIdentifier = nil
        task = nil
        completion?.complete(success: success)
        completion = nil
    }

    private static var title: String {
        String(localized: "Refresh.Progress", table: "Home")
    }

    private static func subtitle(for progress: RefreshProgress) -> String {
        String(localized: "Refresh.Progress.Count \(progress.completed) \(progress.total)", table: "Home")
    }
}

private struct RefreshProgress {
    var completed = 0
    var total = 0

    init() {}

    init(of feedManager: FeedManager) {
        completed = feedManager.refreshCompleted
        total = feedManager.refreshTotal
        for state in feedManager.scopedRefreshes.values {
            completed += state.completed
            total += state.total
        }
    }
}
