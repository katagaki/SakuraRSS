import AppKit

extension MainMenuBuilder {

    /// AppKit retitles the sidebar and toolbar items as they toggle, and adds
    /// the tab bar and full screen items to this menu itself.
    static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.View", table: "Mac"))
        let refreshItem = NSMenuItem(
            title: String(localized: "RefreshFeeds.Title", table: "AppIntents"),
            action: #selector(RefreshActions.refreshFeeds(_:)),
            keyEquivalent: "r"
        )
        menu.addItem(refreshItem)
        let markAllReadItem = NSMenuItem(
            title: String(localized: "MarkAllRead", table: "Articles"),
            action: #selector(BrowserActions.markAllRead(_:)),
            keyEquivalent: "k"
        )
        markAllReadItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(markAllReadItem)
        menu.addItem(.separator())
        menu.addItem(item("Menu.ShowToolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "t",
                          modifiers: [.command, .option]))
        menu.addItem(item("Menu.CustomizeToolbar", action: #selector(NSWindow.runToolbarCustomizationPalette(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Menu.ShowSidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)),
                          keyEquivalent: "s", modifiers: [.command, .control]))
        return menu
    }
}
