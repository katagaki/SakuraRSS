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
        default: true
        }
    }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
}
