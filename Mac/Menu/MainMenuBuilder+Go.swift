import AppKit

extension MainMenuBuilder {

    static func goMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.Go", table: "Mac"))
        let backItem = NSMenuItem(
            title: String(localized: "AddressBar.Back", table: "Browser"),
            action: #selector(BrowserActions.goBack(_:)),
            keyEquivalent: "["
        )
        menu.addItem(backItem)
        menu.addItem(item("Menu.Forward", action: #selector(BrowserActions.goForward(_:)), keyEquivalent: "]"))
        return menu
    }
}
