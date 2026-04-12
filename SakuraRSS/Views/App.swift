import CoreSpotlight
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
                .modifier(KeepScreenOnDuringPodcastWork())
                .task {
                    // Pre-warm the X WKWebsiteDataStore cookie store so
                    // that the first feed refresh sees valid session
                    // cookies.  On cold launch the cookie store is
                    // otherwise empty until a WKWebView has loaded a
                    // page from the domain.
                    //
                    // Instagram has migrated to Keychain-backed cookie
                    // storage, so its cookies are always available
                    // without any WebKit warming — we just run a
                    // one-time migration for users upgrading from a
                    // version that only stored cookies in WebKit.
                    if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                        await XProfileScraper.warmCookieStore()
                    }
                    if UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds") {
                        await InstagramProfileScraper.migrateWebKitCookiesIfNeeded()
                    }
                    await feedManager.refreshAllFeeds()
                    UserDefaults.standard.set(false, forKey: "App.StartupInProgress")
                    feedManager.updateBadgeCount()
                    requestReviewIfNeeded()
                    // Kick off NLP insight processing after startup
                    // completes so it never holds up badge refresh or
                    // any other MainActor-visible work.
                    Task.detached(priority: .utility) {
                        await NLPProcessingCoordinator.processNewArticlesIfEnabled()
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    feedManager.loadFromDatabase()
                    feedManager.updateBadgeCount()
                    WidgetCenter.shared.reloadAllTimelines()
                    Task {
                        await feedManager.refreshUnfetchedFeeds()
                    }
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
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if let articleID = SpotlightIndexer.articleID(from: activity) {
                        pendingArticleID = articleID
                    }
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
            case "howmanybulbs":
                Task {
                    SpotlightIndexer.removeAllArticles()
                    feedManager.reindexAllArticlesInSpotlight()
                }
            case "putonpipboy":
                wipeAllCachesAndData()
                Task {
                    if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                        await XProfileScraper.fetchQueryIDsIfNeeded()
                    }
                    // Instagram cookies live in Keychain, which survives
                    // the filesystem wipe above — no re-warming needed.
                    let entries = feedManager.feeds.map { ($0.domain, $0.siteURL as String?) }
                    await FaviconCache.shared.refreshFavicons(for: entries)
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

    /// Wipes everything in the app's Caches, Application Support, Documents,
    /// and tmp directories except the feeds database in the shared app group
    /// container. Invoked via `sakura://putonpipboy`.
    private func wipeAllCachesAndData() {
        let fm = FileManager.default

        // Wipe the main app sandbox directories entirely.
        let directories: [FileManager.SearchPathDirectory] = [
            .cachesDirectory,
            .applicationSupportDirectory,
            .documentDirectory
        ]
        for searchPath in directories {
            guard let dir = fm.urls(for: searchPath, in: .userDomainMask).first else { continue }
            wipeContents(of: dir)
        }

        // Wipe the temporary directory.
        wipeContents(of: fm.temporaryDirectory)

        // Wipe the shared app group container, but preserve the feeds database.
        if let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) {
            let dbFile = groupURL.appendingPathComponent("Sakura.feeds").lastPathComponent
            let dbWal = groupURL.appendingPathComponent("Sakura.feeds-wal").lastPathComponent
            let dbShm = groupURL.appendingPathComponent("Sakura.feeds-shm").lastPathComponent
            let preserved: Set<String> = [dbFile, dbWal, dbShm]
            wipeContents(of: groupURL, except: preserved)
        }
    }

    /// Removes every top-level entry inside `directory`, except names in `except`.
    private func wipeContents(of directory: URL, except: Set<String> = []) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries {
            if except.contains(entry.lastPathComponent) { continue }
            try? fm.removeItem(at: entry)
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

        // Flag stayed set from last launch → previous startup crashed.
        if defaults.bool(forKey: "App.StartupInProgress") {
            Self.resetSavedNavigationState(defaults: defaults)
        }
        defaults.set(true, forKey: "App.StartupInProgress")

        defaults.set(defaults.integer(forKey: "App.LaunchCount") + 1, forKey: "App.LaunchCount")
        registerBackgroundTask()
        try? Tips.configure()
    }

    private static let navigationStateKeys: [String] = [
        "App.SelectedTab",
        "Home.SelectedSection",
        "Home.FeedID",
        "Home.ArticleID",
        "FeedsList.FeedID",
        "FeedsList.ArticleID"
    ]

    private static func resetSavedNavigationState(defaults: UserDefaults) {
        for key in navigationStateKeys {
            defaults.removeObject(forKey: key)
        }
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
            // Skip X and Instagram profile feeds in background refresh.
            // Both scrapers depend on WKWebView-backed cookie warming
            // (and X additionally on a JS-bundle query-ID fetch) that
            // isn't reliable in a headless BGAppRefreshTask, and firing
            // authenticated API calls from a locked device at a fixed
            // cadence is itself a bot-like signal.  Those feeds refresh
            // when the user actually opens the app instead.
            await manager.refreshAllFeeds(skipAuthenticatedScrapers: true)
            await NLPProcessingCoordinator.processNewArticlesIfEnabled()
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

/// Keeps the device screen awake while any podcast download or transcription
/// is in progress, so long-running work isn't interrupted when the device
/// would otherwise auto-lock.
private struct KeepScreenOnDuringPodcastWork: ViewModifier {
    @State private var manager = PodcastDownloadManager.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: manager.activeDownloads.isEmpty, initial: true) { _, isEmpty in
                UIApplication.shared.isIdleTimerDisabled = !isEmpty
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
}
