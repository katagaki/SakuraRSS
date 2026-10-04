import AppKit
import Hanami

final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var feedManager: FeedManager?
    private var scaffoldWindowController: NSWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuBuilder.build()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let feedManager = FeedManager()
        self.feedManager = feedManager
        let window = NSWindow(contentViewController: FeedTitlesViewController(feedManager: feedManager))
        window.title = "Sakura"
        window.setContentSize(NSSize(width: 480, height: 600))
        let windowController = NSWindowController(window: window)
        windowController.showWindow(nil)
        window.center()
        scaffoldWindowController = windowController
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
