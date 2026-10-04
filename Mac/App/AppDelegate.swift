import AppKit
import Hanami

final class AppDelegate: NSObject, NSApplicationDelegate, RefreshActions {

    private(set) var registry: BrowserWindowRegistry!
    private(set) var refreshCoordinator: RefreshCoordinator!

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
        refreshCoordinator.refreshOnLaunchIfEnabled()
        refreshCoordinator.schedulePeriodicRefresh()
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

    func refreshFeeds(_ sender: Any?) {
        refreshCoordinator.refresh()
    }

    func stopRefreshing(_ sender: Any?) {
        refreshCoordinator.stop()
    }
}
