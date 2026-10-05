import AppKit

/// Rebuilds browser windows, tabs included, from the state AppKit saved when
/// the app last quit.
final class BrowserWindowRestoration: NSObject, NSWindowRestoration {

    static let windowIdentifier = NSUserInterfaceItemIdentifier("BrowserWindow")

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        guard identifier == windowIdentifier,
              let registry = (NSApp.delegate as? AppDelegate)?.registry else {
            completionHandler(nil, nil)
            return
        }
        let history = BrowserHistory(coder: state) ?? BrowserHistory(current: .startPage)
        completionHandler(registry.makeController(history: history).window, nil)
    }
}
