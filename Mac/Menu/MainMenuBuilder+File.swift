import AppKit

extension MainMenuBuilder {

    static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.File", table: "Mac"))
        let newTabItem = NSMenuItem(
            title: String(localized: "Menu.NewTab", table: "Browser"),
            action: #selector(NSResponder.newWindowForTab(_:)),
            keyEquivalent: "t"
        )
        menu.addItem(newTabItem)
        menu.addItem(item("Menu.NewWindow", action: #selector(BrowserActions.newBrowserWindow(_:)), keyEquivalent: "n"))
        menu.addItem(.separator())
        menu.addItem(item("Menu.Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        return menu
    }
}
