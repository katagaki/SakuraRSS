import SwiftUI
import BackgroundTasks
import TipKit

@main
struct SakuraRSSApp: App {

    @State private var feedManager = FeedManager()
    @State private var pendingFeedURL: String?
    @State private var pendingArticleID: Int64?
    @State private var isInSafeMode: Bool
    private let backgroundTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"

    var body: some Scene {
        WindowGroup {
            MainTabView(pendingFeedURL: $pendingFeedURL, pendingArticleID: $pendingArticleID,
                        isInSafeMode: $isInSafeMode)
                .environment(\.defaultMinListRowHeight, 10.0)
                .environment(feedManager)
                .task {
                    if !isInSafeMode {
                        await feedManager.refreshAllFeeds()
                    }
                    UserDefaults.standard.set(false, forKey: "App.StartupInProgress")
                    feedManager.updateBadgeCount()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    feedManager.loadFromDatabase()
                    feedManager.updateBadgeCount()
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
    }

    private func handleOpenURL(_ url: URL) {
        if url.scheme == "sakura", url.host == "article",
           let idString = url.pathComponents.last,
           let articleID = Int64(idString) {
            pendingArticleID = articleID
        } else {
            pendingFeedURL = convertFeedURL(url)
        }
    }

    private func convertFeedURL(_ url: URL) -> String {
        let urlString = url.absoluteString
        if urlString.hasPrefix("feed:https://") || urlString.hasPrefix("feed:http://") {
            return String(urlString.dropFirst("feed:".count))
        } else if urlString.hasPrefix("feeds:https://") || urlString.hasPrefix("feeds:http://") {
            return String(urlString.dropFirst("feeds:".count))
        } else if urlString.hasPrefix("feed://") {
            return "https://" + urlString.dropFirst("feed://".count)
        } else if urlString.hasPrefix("feeds://") {
            return "https://" + urlString.dropFirst("feeds://".count)
        }
        return urlString
    }

    init() {
        let defaults = UserDefaults.standard
        let wasStartupInProgress = defaults.bool(forKey: "App.StartupInProgress")

        if wasStartupInProgress {
            _isInSafeMode = State(initialValue: true)
            defaults.removeObject(forKey: "App.SelectedTab")
            defaults.removeObject(forKey: "Home.FeedID")
            defaults.removeObject(forKey: "Home.ArticleID")
            defaults.removeObject(forKey: "FeedsList.FeedID")
            defaults.removeObject(forKey: "FeedsList.ArticleID")
        } else {
            _isInSafeMode = State(initialValue: false)
        }

        defaults.set(true, forKey: "App.StartupInProgress")
        registerBackgroundTask()
        try? Tips.configure()
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskID,
            using: nil
        ) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: task)
        }
        scheduleAppRefresh()
    }

    private func scheduleAppRefresh() {
        let isEnabled = UserDefaults.standard.object(forKey: "BackgroundRefresh.Enabled") as? Bool ?? true
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundTaskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskID)
        let refreshInterval = UserDefaults.standard.integer(forKey: "BackgroundRefresh.Interval")
        let minutes = refreshInterval > 0 ? refreshInterval : 60
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(minutes * 60))
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()

        let refreshTask = Task {
            let manager = FeedManager()
            await manager.refreshAllFeeds()
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

}
