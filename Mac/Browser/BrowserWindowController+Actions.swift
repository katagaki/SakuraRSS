import AppKit

extension BrowserWindowController: BrowserActions, NSMenuItemValidation, NSToolbarItemValidation {

    override func newWindowForTab(_ sender: Any?) {
        guard let window else { return }
        appDelegate?.registry.openTab(beside: window)
    }

    func newBrowserWindow(_ sender: Any?) {
        appDelegate?.registry.openWindow()
    }

    func focusAddressField(_ sender: Any?) {
        addressBarController.focus()
    }

    func markAllRead(_ sender: Any?) {
        history.current.markAllReadAction(in: feedManager)?()
    }

    func followNewFeed(_ sender: Any?) {
        presentAddFeedSheet(for: "")
    }

    func createList(_ sender: Any?) {
        contentViewController?.presentSwiftUISheet(ListEditSheet(list: nil), feedManager: feedManager)
    }

    func goBack(_ sender: Any?) {
        updateHistory { $0.goBack() }
    }

    func goForward(_ sender: Any?) {
        updateHistory { $0.goForward() }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validate(menuItem.action)
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        validate(item.action)
    }

    private func validate(_ action: Selector?) -> Bool {
        switch action {
        case #selector(goBack(_:)): history.canGoBack
        case #selector(goForward(_:)): history.canGoForward
        case #selector(markAllRead(_:)): history.current.markAllReadAction(in: feedManager) != nil
        default: true
        }
    }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
}
