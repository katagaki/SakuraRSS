import AppKit

extension MainMenuBuilder {

    /// AppKit retitles the sidebar and toolbar items as they toggle, and adds
    /// the tab bar and full screen items to this menu itself.
    static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.View", table: "Mac"))
        menu.addItem(item("Menu.ShowToolbar", action: #selector(NSWindow.toggleToolbarShown(_:)), keyEquivalent: "t",
                          modifiers: [.command, .option]))
        menu.addItem(item("Menu.CustomizeToolbar", action: #selector(NSWindow.runToolbarCustomizationPalette(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Menu.ShowSidebar", action: #selector(NSSplitViewController.toggleSidebar(_:)),
                          keyEquivalent: "s", modifiers: [.command, .control]))
        return menu
    }
}
