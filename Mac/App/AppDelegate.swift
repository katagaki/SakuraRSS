import AppKit
import Hanami

final class AppDelegate: NSObject, NSApplicationDelegate, RefreshActions {

    private(set) var registry: BrowserWindowRegistry!
    private(set) var refreshCoordinator: RefreshCoordinator!
    private var settingsWindowController: SettingsWindowController?
    private var dockBadgeCoordinator: DockBadgeCoordinator?
    private let backupScheduler = BackupScheduler()
    private var defaultsObserver: NSObjectProtocol?
    private var schedulingSettings = SchedulingSettings.current

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.build()
        let feedManager = FeedManager()
        registry = BrowserWindowRegistry(feedManager: feedManager)
        refreshCoordinator = RefreshCoordinator(feedManager: feedManager)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if registry.controllers.isEmpty {
            registry.openWindow()
        }
        connectServices()
        refreshCoordinator.refreshOnLaunchIfEnabled()
        refreshCoordinator.schedulePeriodicRefresh()
        AutomaticCleanupScheduler.scheduleNextCleanup()
        backupScheduler.schedule()
        observeSchedulingSettings()
        dockBadgeCoordinator = DockBadgeCoordinator(feedManager: registry.feedManager)
        #if DEBUG
        DebugLaunchActions.perform(with: registry)
        DebugSnapshotRenderer.scheduleIfRequested()
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, registry.controllers.isEmpty {
            registry.openWindow()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc func newWindowForTab(_ sender: Any?) {
        registry.openWindow()
    }

    @objc func newBrowserWindow(_ sender: Any?) {
        registry.openWindow()
    }

    /// What iOS connects at startup, with iCloud sync only when this build is
    /// signed with CloudKit.
    private func connectServices() {
        let feedManager = registry.feedManager
        feedManager.connectProviderSessions()
        if AppEntitlements.hasCloudKit {
            feedManager.connectCloudSync()
        }
        Task {
            await FeedProviderRegistry.migrateAuthenticatedCookies()
        }
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(feedManager: registry.feedManager)
            settingsWindowController?.window?.center()
        }
        settingsWindowController?.showWindow(nil)
    }

    /// Settings changes land in user defaults; the schedules that read them
    /// are rebuilt when they do.
    private func observeSchedulingSettings() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rescheduleIfSettingsChanged()
            }
        }
    }

    private func rescheduleIfSettingsChanged() {
        let latest = SchedulingSettings.current
        guard latest != schedulingSettings else { return }
        if latest.isPeriodicRefreshEnabled != schedulingSettings.isPeriodicRefreshEnabled
            || latest.refreshInterval != schedulingSettings.refreshInterval {
            refreshCoordinator.schedulePeriodicRefresh()
        }
        if latest.isAutomaticCleanupEnabled != schedulingSettings.isAutomaticCleanupEnabled
            || latest.cleanupCutoff != schedulingSettings.cleanupCutoff {
            AutomaticCleanupScheduler.scheduleNextCleanup()
        }
        if latest.backupInterval != schedulingSettings.backupInterval {
            backupScheduler.schedule()
        }
        schedulingSettings = latest
    }

    func refreshFeeds(_ sender: Any?) {
        refreshCoordinator.refresh()
    }

    func stopRefreshing(_ sender: Any?) {
        refreshCoordinator.stop()
    }
}
