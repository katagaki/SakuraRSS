import AppKit
import Hanami

/// The display style menu, shared by the toolbar and the View menu.
extension BrowserWindowController {

    var displayStyleContext: ContentStyleContext? {
        let location = history.current
        guard location.styleKey != nil else { return nil }
        let articles = ContentQuery(feedManager: feedManager).articles(for: location)
        return ContentStyleContext(location: location, articles: articles, feedManager: feedManager)
    }

    func populateDisplayStyleMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let context = displayStyleContext else { return }
        let current = context.effectiveStyle
        for (index, section) in context.menuSections.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            menu.addItem(.sectionHeader(title: section.title))
            for style in section.styles {
                let item = ActionMenuItem(style.localizedName, symbolName: style.symbol) { [weak self] in
                    self?.applyDisplayStyle(style)
                }
                item.state = style == current ? .on : .off
                menu.addItem(item)
            }
        }
    }

    func applyDisplayStyle(_ style: FeedDisplayStyle) {
        displayStyleContext?.save(style)
        splitViewController.detailViewController.reloadStyle(at: history.current)
        toolbarController.updateDisplayStyleItem(context: displayStyleContext)
    }
}

/// Fills the View menu's Display Style submenu from whichever window is key.
final class DisplayStyleMenuDelegate: NSObject, NSMenuDelegate {

    static let shared = DisplayStyleMenuDelegate()

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        (NSApp.keyWindow?.windowController as? BrowserWindowController)?.populateDisplayStyleMenu(menu)
    }
}
