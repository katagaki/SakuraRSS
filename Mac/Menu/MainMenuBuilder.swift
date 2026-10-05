import AppKit

enum MainMenuBuilder {

    static func build() -> NSMenu {
        let mainMenu = NSMenu()
        let windowMenu = windowMenu()
        let helpMenu = NSMenu(title: String(localized: "Menu.Help", table: "Mac"))
        for submenu in [applicationMenu(), fileMenu(), editMenu(), viewMenu(), goMenu(), windowMenu, helpMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            mainMenu.addItem(item)
        }
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
        return mainMenu
    }

    static var applicationName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? ProcessInfo.processInfo.processName
    }

    static func item(
        _ key: String,
        action: Selector?,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: String(localized: String.LocalizationValue(key), table: "Mac"),
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    static func formattedItem(
        _ key: String,
        action: Selector?,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let title = String(format: String(localized: String.LocalizationValue(key), table: "Mac"), applicationName)
        return NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    }
}
