import CoreSpotlight
import SwiftUI
import BackgroundTasks
import StoreKit
import TipKit
import WidgetKit

@main
struct SakuraRSSApp: App {

    @Environment(\.requestReview) var requestReview
    @State var feedManager = FeedManager()
    @State var pendingFeedURL: String?
    @State var pendingArticleID: Int64?
    @State var pendingOpenRequest: OpenArticleRequest?
    @State private var lastForegroundWorkAt: Date?
    @AppStorage("ForceWhileYouSlept") var forceWhileYouSlept: Bool = false
    @AppStorage("ForceTodaysSummary") var forceTodaysSummary: Bool = false
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("BackgroundRefresh.Interval") private var refreshInterval: Int = 240
    @AppStorage("App.FetchOnStartup") private var fetchOnStartup: Bool = true
    @AppStorage("iCloudBackup.Interval")
    private var iCloudBackupInterval: Int = iCloudBackupManager.BackupInterval.everyNight.rawValue
    let backgroundTaskID = "com.tsubuzaki.SakuraRSS.RefreshFeeds"
    let iCloudBackupTaskID = "com.tsubuzaki.SakuraRSS.iCloudBackup"

    var body: some Scene {
        WindowGroup {
            MainTabView(
                pendingFeedURL: $pendingFeedURL,
                pendingArticleID: $pendingArticleID,
                pendingOpenRequest: $pendingOpenRequest
            )
                .environment(\.defaultMinListRowHeight, 10.0)
                .environment(feedManager)
                .keepScreenOnDuringPodcastWork()
                .task {
                    await FeedProviderRegistry.migrateAuthenticatedCookies()
                    if fetchOnStartup {
                        await feedManager.refreshAllFeeds(
                            respectCooldown: true,
                            runNLPAfter: true
                        )
                    }
                    UserDefaults.standard.set(false, forKey: "App.StartupInProgress")
                    feedManager.updateBadgeCount()
                    requestReviewIfNeeded()
                    reindexSpotlightIfSchemaChanged()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                ) { _ in
                    feedManager.flushDebouncedReads()
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    feedManager.updateBadgeCount()
                    let now = Date()
                    if let last = lastForegroundWorkAt, now.timeIntervalSince(last) < 5 * 60 {
                        return
                    }
                    lastForegroundWorkAt = now
                    WidgetCenter.shared.reloadAllTimelines()
                    Task {
                        await feedManager.loadFromDatabaseInBackground()
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
        #if os(visionOS)
        .defaultSize(width: 600, height: 900)
        #endif
        #if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenProfileSettingsButton()
            }
        }
        #endif

        #if os(visionOS)
        WindowGroup(id: "YouTubePlayerWindow", for: Int64.self) { $articleID in
            DetachedYouTubePlayerWindow(articleID: articleID)
                .environment(feedManager)
        }
        .defaultSize(width: 900, height: 600)
        WindowGroup(id: "PodcastPlayerWindow", for: Int64.self) { $articleID in
            DetachedPodcastPlayerWindow(articleID: articleID)
                .environment(feedManager)
        }
        .defaultSize(width: 600, height: 900)
        #endif

        #if targetEnvironment(macCatalyst)
        WindowGroup(id: "ProfileWindow") {
            MoreView(showsCloseButton: false)
                .environment(feedManager)
        }
        .defaultSize(width: 700, height: 700)
        .commandsRemoved()
        #endif
    }

    init() {
        let defaults = UserDefaults.standard

        defaults.register(defaults: [
            "Intelligence.ContentInsights.Enabled": true
        ])
        Self.enableHomeTopicsByDefaultIfNeeded(defaults: defaults)

        if defaults.bool(forKey: "App.StartupInProgress") {
            Self.resetSavedNavigationState(defaults: defaults)
        }
        defaults.set(true, forKey: "App.StartupInProgress")

        defaults.set(defaults.integer(forKey: "App.LaunchCount") + 1, forKey: "App.LaunchCount")
        registerBackgroundTask()
        try? Tips.configure()
    }

    private static func enableHomeTopicsByDefaultIfNeeded(defaults: UserDefaults) {
        let key = "Home.BarConfiguration.TopicsDefaultEnabled.Migrated"
        guard !defaults.bool(forKey: key) else { return }
        var config = HomeBarConfiguration.load()
        if !config.enabledItems.contains(.topics) {
            config.enabledItems.insert(.topics)
            config.save()
        }
        defaults.set(true, forKey: key)
    }
}
