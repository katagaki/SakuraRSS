import AppKit

extension MainMenuBuilder {

    /// AppKit fills in the tab items and the list of open windows.
    static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.Window", table: "Mac"))
        menu.addItem(item("Menu.Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        menu.addItem(item("Menu.Zoom", action: #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Menu.BringAllToFront", action: #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }
}
