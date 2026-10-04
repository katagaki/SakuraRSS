import AppKit

extension MainMenuBuilder {

    static func editMenu() -> NSMenu {
        let menu = NSMenu(title: String(localized: "Menu.Edit", table: "Mac"))
        menu.addItem(item("Menu.Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        menu.addItem(item("Menu.Redo", action: Selector(("redo:")), keyEquivalent: "z", modifiers: [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Menu.Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(item("Menu.Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(item("Menu.Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(item("Menu.SelectAll", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        return menu
    }
}
