import AppKit
import Hanami

extension SidebarViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let node = outlineView.item(atRow: outlineView.clickedRow) as? SidebarNode,
              let location = node.location else { return }
        populate(menu, for: location)
    }

    func populate(_ menu: NSMenu, for location: BrowserLocation) {
        menu.addItem(ActionMenuItem(
            String(localized: "Menu.OpenInNewTab", table: "Browser"),
            symbolName: "plus.square.on.square"
        ) { [weak self] in
            self?.onOpenInNewTab?(location)
        })
        if let markAllRead = location.markAllReadAction(in: feedManager) {
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem(
                String(localized: "MarkAllRead", table: "Articles"),
                symbolName: "checkmark.circle",
                handler: markAllRead
            ))
        }
        switch location {
        case .feed(let feedID):
            guard let feed = feedManager.feedsByID[feedID] else { return }
            addFeedItems(for: feed, to: menu)
        case .list(let listID):
            guard let list = feedManager.lists.first(where: { $0.id == listID }) else { return }
            menu.addItem(.separator())
            let editTitle = String(localized: "ListMenu.Edit", table: "Lists")
            menu.addItem(ActionMenuItem(editTitle, symbolName: "pencil") { [weak self] in
                guard let self else { return }
                self.presentSwiftUISheet(ListEditSheet(list: list), feedManager: self.feedManager)
            })
            menu.addItem(ActionMenuItem(
                String(localized: "ListMenu.Rules", table: "Lists"),
                symbolName: "line.3.horizontal.decrease.circle"
            ) { [weak self] in
                guard let self else { return }
                self.presentSwiftUISheet(ListRulesSheet(list: list), feedManager: self.feedManager)
            })
            let deleteTitle = String(localized: "ListMenu.Delete", table: "Lists")
            menu.addItem(ActionMenuItem(deleteTitle, symbolName: "trash") { [weak self] in
                self?.confirmDeleting(list)
            })
        default:
            break
        }
    }

    private func addFeedItems(for feed: Feed, to menu: NSMenu) {
        if let url = URL(string: feed.url) {
            menu.addItem(ActionMenuItem(String(localized: "Article.CopyLink", table: "Articles"), symbolName: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
            })
        }
        menu.addItem(.separator())
        let unfollowTitle = String(localized: "FeedMenu.Unfollow", table: "Feeds")
        menu.addItem(ActionMenuItem(unfollowTitle, symbolName: "minus.circle") { [weak self] in
            self?.confirmUnfollowing(feed)
        })
    }
}
