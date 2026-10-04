import AppKit

extension MainMenuBuilder {

    static func applicationMenu() -> NSMenu {
        let menu = NSMenu(title: applicationName)
        menu.addItem(formattedItem(
            "Menu.About",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        ))
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: String(localized: "Menu.Settings", table: "Settings"),
            action: #selector(AppDelegate.showSettings(_:)),
            keyEquivalent: ","
        )
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        let servicesItem = item("Menu.Services", action: nil)
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        menu.addItem(servicesItem)
        menu.addItem(.separator())
        menu.addItem(formattedItem("Menu.Hide", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        menu.addItem(item(
            "Menu.HideOthers",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h",
            modifiers: [.command, .option]
        ))
        menu.addItem(item("Menu.ShowAll", action: #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(formattedItem("Menu.Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
}
