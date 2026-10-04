import AppKit

/// A menu item that runs a closure, for context menus built in code.
/// `NSMenuItem` isn't main actor isolated, so neither is this; its handler
/// only ever runs from a menu, on the main thread.
nonisolated final class ActionMenuItem: NSMenuItem {

    private let handler: @MainActor () -> Void

    init(_ title: String, symbolName: String? = nil, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
        if let symbolName {
            image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func runHandler() {
        let handler = handler
        MainActor.assumeIsolated {
            handler()
        }
    }
}
