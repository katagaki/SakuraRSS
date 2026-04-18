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
    @State private var lastForegroundWorkAt: Date?
    @AppStorage("ForceWhileYouSlept") private var forceWhileYouSlept: Bool = false
    @AppStorage("ForceTodaysSummary") private var forceTodaysSummary: Bool = false
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 240
    @AppStorage("iCloudBackup.Interval") private var iCloudBackupInterval: Int = iCloudBackupManager.BackupInterval.everyNight.rawValue
    private let backgroundTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"
    private let iCloudBackupTaskID = "com.tsubuzaki.SakuraRSS.iCloudBackup"

    var body: some Scene {
        WindowGroup {
            MainTabView(pendingFeedURL: $pendingFeedURL, pendingArticleID: $pendingArticleID)
                .environment(\.defaultMinListRowHeight, 10.0)
                .environment(feedManager)
                .modifier(KeepScreenOnDuringPodcastWork())
                .task {
                    // Both X and Instagram now use Keychain-backed cookie
                    // storage, so their cookies are available without any
                    // WebKit warming on cold launch.  We run a one-time
                    // migration for users upgrading from versions that
                    // only stored cookies in WebKit.
                    if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                        await XProfileScraper.migrateWebKitCookiesIfNeeded()
                    }
                    if UserDefaults.standard.bool(forKey: "Labs.InstagramProfileFeeds") {
                        await InstagramProfileScraper.migrateWebKitCookiesIfNeeded()
                    }
                    await feedManager.refreshAllFeeds(respectCooldown: true)
                    UserDefaults.standard.set(false, forKey: "App.StartupInProgress")
                    feedManager.updateBadgeCount()
                    requestReviewIfNeeded()
                    reindexSpotlightIfSchemaChanged()
                    // Kick off NLP insight processing after startup
                    // completes so it never holds up badge refresh or
                    // any other MainActor-visible work.  Skip entirely
                    // under Low Power Mode - NLTagger work is deferred
                    // until LPM turns off.
                    if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                        Task.detached(priority: .utility) {
                            await NLPProcessingCoordinator.processNewArticlesIfEnabled()
                        }
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                ) { _ in
                    // Make sure any debounced mark-as-read-on-scroll
                    // updates are fully applied (full reload + badge)
                    // before the app suspends.
                    feedManager.flushDebouncedReads()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    // Always update the badge - cheap and user-visible.
                    feedManager.updateBadgeCount()
                    // Debounce the rest of the foreground chain.  Rapid
                    // app switches trigger willEnterForeground every
                    // time, and re-running the DB reload + widget
                    // reload + unfetched-feed refresh each time is
                    // wasted energy when nothing has had time to change.
                    let now = Date()
                    if let last = lastForegroundWorkAt, now.timeIntervalSince(last) < 5 * 60 {
                        return
                    }
                    lastForegroundWorkAt = now
                    feedManager.loadFromDatabase()
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
                .onChange(of: iCloudBackupInterval) {
                    scheduleiCloudBackup()
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

    /// Runs a one-time full Spotlight reindex when the on-device index
    /// schema doesn't match the current build's `SpotlightIndexer.schemaVersion`.
    /// Does NOT gate on Low Power Mode: if the schema has changed, search
    /// is broken until the reindex runs.  In the steady state - when the
    /// stored version already matches - this method is a single
    /// `UserDefaults` read and returns immediately.
    private func reindexSpotlightIfSchemaChanged() {
        let defaults = UserDefaults.standard
        let storedRaw = defaults.object(forKey: SpotlightIndexer.schemaVersionDefaultsKey) as? Int
        guard storedRaw != SpotlightIndexer.schemaVersion else { return }

        SpotlightIndexer.removeAllArticles()
        feedManager.reindexAllArticlesInSpotlight()
        defaults.set(SpotlightIndexer.schemaVersion, forKey: SpotlightIndexer.schemaVersionDefaultsKey)
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
            case "bigbang":
                feedManager.markAllUnread()
            case "howmanybulbs":
                Task {
                    SpotlightIndexer.removeAllArticles()
                    feedManager.reindexAllArticlesInSpotlight()
                }
            case "putonpipboy":
                wipeAllCachesAndData()
                Task {
                    // X and Instagram cookies live in Keychain, which
                    // survives the filesystem wipe above - no cookie
                    // re-warming needed.  X still has to re-extract its
                    // in-memory GraphQL query IDs from the JS bundle.
                    if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                        await XProfileScraper.fetchQueryIDsIfNeeded()
                    }
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

    private func scheduleAppRefresh() {
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

    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Always reschedule the next window before deciding what to run.
        scheduleAppRefresh()

        // Respect Low Power Mode: do no background work at all, just
        // complete cleanly so the system doesn't count this as a failure.
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            task.setTaskCompleted(success: true)
            return
        }

        let refreshTask = Task {
            let manager = FeedManager()
            await manager.refreshAllFeeds(
                skipAuthenticatedScrapers: true,
                respectCooldown: true
            )
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

    /// Submits a `BGProcessingTaskRequest` for the iCloud backup, requiring
    /// network connectivity and external power so the system runs it during
    /// idle/charging windows (typically overnight on Wi-Fi). Cancelled if the
    /// user has set the backup interval to Off.
    private func scheduleiCloudBackup() {
        let intervalRaw = UserDefaults.standard.integer(forKey: "iCloudBackup.Interval")
        let interval = iCloudBackupManager.BackupInterval(rawValue: intervalRaw) ?? .everyNight
        guard interval != .off else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: iCloudBackupTaskID)
            return
        }
        let request = BGProcessingTaskRequest(identifier: iCloudBackupTaskID)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(interval.rawValue))
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleiCloudBackup(task: BGProcessingTask) {
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
