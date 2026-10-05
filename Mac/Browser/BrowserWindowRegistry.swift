import AppKit
import Hanami

/// Keeps every browser window's controller alive, since AppKit only holds
/// the windows themselves.
final class BrowserWindowRegistry {

    let feedManager: FeedManager
    private(set) var controllers: [BrowserWindowController] = []

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
    }

    func makeController(history: BrowserHistory = BrowserHistory(current: .startPage)) -> BrowserWindowController {
        let controller = BrowserWindowController(feedManager: feedManager, history: history)
        controller.onClose = { [weak self] closed in
            self?.controllers.removeAll { $0 === closed }
        }
        controllers.append(controller)
        return controller
    }

    @discardableResult
    func openWindow(history: BrowserHistory = BrowserHistory(current: .startPage)) -> BrowserWindowController {
        let controller = makeController(history: history)
        if let frontmost = controllers.dropLast().last?.window, let window = controller.window {
            window.setFrameTopLeftPoint(NSPoint(x: frontmost.frame.minX + 24, y: frontmost.frame.maxY - 24))
        } else {
            controller.window?.center()
        }
        controller.showWindow(nil)
        return controller
    }

    func openTab(beside window: NSWindow, history: BrowserHistory = BrowserHistory(current: .startPage)) {
        let controller = makeController(history: history)
        guard let tab = controller.window else { return }
        window.addTabbedWindow(tab, ordered: .above)
        tab.makeKeyAndOrderFront(nil)
    }
}
