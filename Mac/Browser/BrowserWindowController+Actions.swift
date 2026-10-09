import AppKit
import Hanami

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

    func toggleHideReadContent(_ sender: Any?) {
        guard let pageKey = currentHideReadContentPageKey else { return }
        feedManager.setHidesReadContent(!feedManager.hidesReadContent(onPage: pageKey), onPage: pageKey)
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
        if menuItem.action == #selector(toggleHideReadContent(_:)) {
            let isOn = currentHideReadContentPageKey.map(feedManager.hidesReadContent(onPage:)) ?? false
            menuItem.state = isOn ? .on : .off
        }
        return validate(menuItem.action)
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        validate(item.action)
    }

    private func validate(_ action: Selector?) -> Bool {
        switch action {
        case #selector(goBack(_:)): history.canGoBack
        case #selector(goForward(_:)): history.canGoForward
        case #selector(markAllRead(_:)): history.current.markAllReadAction(in: feedManager) != nil
        case #selector(toggleHideReadContent(_:)): currentHideReadContentPageKey != nil
        default: true
        }
    }

    /// Doomscrolling Mode always shows read content, so there's nothing to toggle.
    private var currentHideReadContentPageKey: String? {
        guard !DoomscrollingMode.isEnabled else { return nil }
        return history.current.pageKey(in: feedManager)
    }

    private var appDelegate: AppDelegate? {
        NSApp.delegate as? AppDelegate
    }
}
