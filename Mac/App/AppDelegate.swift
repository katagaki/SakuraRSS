import AppKit
import Hanami

final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var registry: BrowserWindowRegistry!

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.build()
        registry = BrowserWindowRegistry(feedManager: FeedManager())
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if registry.controllers.isEmpty {
            registry.openWindow()
        }
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
}
