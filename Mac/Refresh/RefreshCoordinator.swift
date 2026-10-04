import Foundation
import Hanami

/// Fetches new content on launch, on request, and periodically. The periodic
/// refresh goes through `NSBackgroundActivityScheduler`, so macOS can defer
/// it to a moment that suits the battery and network.
final class RefreshCoordinator {

    let feedManager: FeedManager
    private var scheduler: NSBackgroundActivityScheduler?

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
    }

    func refreshOnLaunchIfEnabled() {
        let fetchesOnStartup = UserDefaults.standard.object(forKey: "App.FetchOnStartup") as? Bool ?? true
        guard fetchesOnStartup else { return }
        refresh(respectingCooldown: true)
    }

    func refresh(respectingCooldown: Bool = false) {
        guard !feedManager.isLoading else { return }
        Task {
            await feedManager.refreshAllFeeds(respectCooldown: respectingCooldown, runNLPAfter: true)
        }
    }

    func stop() {
        feedManager.cancelRefresh()
    }

    func schedulePeriodicRefresh() {
        scheduler?.invalidate()
        scheduler = nil
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else { return }
        let minutes = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
        let interval = TimeInterval((minutes > 0 ? minutes : 240) * 60)
        let scheduler = NSBackgroundActivityScheduler(identifier: "com.tsubuzaki.SakuraRSS.Refresh")
        scheduler.repeats = true
        scheduler.interval = interval
        scheduler.tolerance = interval / 4
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            Task { @MainActor in
                guard let self, !self.feedManager.isLoading else {
                    completion(.finished)
                    return
                }
                await self.feedManager.refreshAllFeeds(respectCooldown: true, runNLPAfter: true)
                completion(.finished)
            }
        }
        self.scheduler = scheduler
    }
}
