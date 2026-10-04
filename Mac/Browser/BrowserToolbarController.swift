import AppKit

final class BrowserToolbarController: NSObject, NSToolbarDelegate {

    private enum ItemIdentifier {
        static let back = NSToolbarItem.Identifier("Back")
        static let forward = NSToolbarItem.Identifier("Forward")
        static let newTab = NSToolbarItem.Identifier("NewTab")
        static let address = NSToolbarItem.Identifier("Address")
        static let refresh = NSToolbarItem.Identifier("Refresh")
    }

    let toolbar: NSToolbar
    private let addressField: NSView
    private let refreshButton: NSView

    init(addressField: NSView, refreshButton: NSView) {
        self.addressField = addressField
        self.refreshButton = refreshButton
        toolbar = NSToolbar(identifier: "BrowserToolbar")
        super.init()
        toolbar.delegate = self
        toolbar.centeredItemIdentifiers = [ItemIdentifier.address]
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.toggleSidebar, .sidebarTrackingSeparator, ItemIdentifier.back, ItemIdentifier.forward,
         .flexibleSpace, ItemIdentifier.address, .flexibleSpace, ItemIdentifier.refresh, ItemIdentifier.newTab]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case ItemIdentifier.back:
            navigationalButton(button(itemIdentifier, String(localized: "AddressBar.Back", table: "Browser"),
                                      "chevron.backward", #selector(BrowserActions.goBack(_:))))
        case ItemIdentifier.forward:
            navigationalButton(button(itemIdentifier, String(localized: "Menu.Forward", table: "Mac"),
                                      "chevron.forward", #selector(BrowserActions.goForward(_:))))
        case ItemIdentifier.address:
            addressItem()
        case ItemIdentifier.refresh:
            refreshItem()
        case ItemIdentifier.newTab:
            button(itemIdentifier, String(localized: "Menu.NewTab", table: "Browser"), "plus",
                   #selector(NSResponder.newWindowForTab(_:)))
        default:
            nil
        }
    }

    private func addressItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: ItemIdentifier.address)
        let label = String(localized: "AddressField.Prompt", table: "Browser")
        item.label = label
        item.paletteLabel = label
        addressField.translatesAutoresizingMaskIntoConstraints = false
        let preferredWidth = addressField.widthAnchor.constraint(equalToConstant: 520)
        preferredWidth.priority = .defaultLow
        NSLayoutConstraint.activate([
            addressField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            addressField.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            preferredWidth
        ])
        item.view = addressField
        item.visibilityPriority = .high
        item.isBordered = true
        return item
    }

    private func refreshItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: ItemIdentifier.refresh)
        let label = String(localized: "RefreshFeeds.ShortTitle", table: "AppIntents")
        item.label = label
        item.paletteLabel = label
        item.view = refreshButton
        return item
    }

    private func navigationalButton(_ item: NSToolbarItem) -> NSToolbarItem {
        item.isNavigational = true
        return item
    }

    private func button(
        _ identifier: NSToolbarItem.Identifier,
        _ label: String,
        _ symbolName: String,
        _ action: Selector
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        item.action = action
        item.isBordered = true
        return item
    }
}
