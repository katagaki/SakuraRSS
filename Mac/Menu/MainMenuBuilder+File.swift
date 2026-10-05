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
        menu.addItem(item(
            "Menu.OpenLocation",
            action: #selector(BrowserActions.focusAddressField(_:)),
            keyEquivalent: "l"
        ))
        menu.addItem(.separator())
        let followItem = NSMenuItem(
            title: String(localized: "Sidebar.AddFeed", table: "Feeds"),
            action: #selector(BrowserActions.followNewFeed(_:)),
            keyEquivalent: "n"
        )
        followItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(followItem)
        let createListItem = NSMenuItem(
            title: String(localized: "Sidebar.CreateList", table: "Feeds"),
            action: #selector(BrowserActions.createList(_:)),
            keyEquivalent: "n"
        )
        createListItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(createListItem)
        menu.addItem(.separator())
        menu.addItem(item("Menu.Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        return menu
    }
}
