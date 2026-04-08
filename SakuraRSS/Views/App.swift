import SwiftUI
import BackgroundTasks
import StoreKit
import TipKit
import WidgetKit

@main
struct SakuraRSSApp: App {

    @Environment(\.requestReview) private var requestReview
    @State private var feedManager = FeedManager()
    @State private var pendingFeedURL: String?
    @State private var pendingArticleID: Int64?
    @AppStorage("ForceWhileYouSlept") private var forceWhileYouSlept: Bool = false
    @AppStorage("ForceTodaysSummary") private var forceTodaysSummary: Bool = false
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 60
    private let backgroundTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"

    var body: some Scene {
        WindowGroup {
            MainTabView(pendingFeedURL: $pendingFeedURL, pendingArticleID: $pendingArticleID)
                .environment(\.defaultMinListRowHeight, 10.0)
                .environment(feedManager)
                .task {
                    await feedManager.refreshAllFeeds()
                    UserDefaults.standard.set(false, forKey: "App.StartupInProgress")
                    feedManager.updateBadgeCount()
                    requestReviewIfNeeded()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    feedManager.loadFromDatabase()
                    feedManager.updateBadgeCount()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onChange(of: backgroundRefreshEnabled) {
                    scheduleAppRefresh()
                }
                .onChange(of: refreshInterval) {
                    scheduleAppRefresh()
                }
                .onOpenURL { url in
                    handleOpenURL(url)
                }
        }
    }

    private func requestReviewIfNeeded() {
        let launchCount = UserDefaults.standard.integer(forKey: "App.LaunchCount")
        if launchCount == 3 {
            requestReview()
        }
    }

    private func handleOpenURL(_ url: URL) {
        if url.scheme == "sakura" {
            switch url.host {
            case "article":
                if let idString = url.pathComponents.last,
                   let articleID = Int64(idString) {
                    pendingArticleID = articleID
                }
            case "justwokeup":
                forceWhileYouSlept = true
                UserDefaults.standard.removeObject(forKey: "WhileYouSlept.DismissedDate")
            case "justgothome":
                forceTodaysSummary = true
                UserDefaults.standard.removeObject(forKey: "TodaysSummary.DismissedDate")
            case "reonboard":
                UserDefaults.standard.set(false, forKey: "Onboarding.Completed")
            case "fixup":
                DatabaseManager.shared.fixup()
                UserDefaults.standard.removeObject(forKey: "App.DatabaseVersion")
            case "arisishere":
                Task {
                    await feedManager.deleteAllArticlesAndRefresh()
                }
            case "forgetit":
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "App.SelectedTab")
                defaults.removeObject(forKey: "Home.FeedID")
                defaults.removeObject(forKey: "Home.ArticleID")
                defaults.removeObject(forKey: "FeedsList.FeedID")
                defaults.removeObject(forKey: "FeedsList.ArticleID")
                defaults.removeObject(forKey: "Display.DefaultStyle")
                defaults.removeObject(forKey: "Search.DisplayStyle")
                defaults.removeObject(forKey: "Display.DefaultBookmarksStyle")
                defaults.removeObject(forKey: "TodaysSummary.DismissedDate")
                defaults.removeObject(forKey: "WhileYouSlept.DismissedDate")
                defaults.removeObject(forKey: "ForceWhileYouSlept")
                defaults.removeObject(forKey: "ForceTodaysSummary")
                for key in defaults.dictionaryRepresentation().keys {
                    if key.hasPrefix("Display.Style.") || key.hasPrefix("openMode-")
                        || key.hasPrefix("Labs.") {
                        defaults.removeObject(forKey: key)
                    }
                }
            default:
                break
            }
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
        defaults.set(defaults.integer(forKey: "App.LaunchCount") + 1, forKey: "App.LaunchCount")
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
