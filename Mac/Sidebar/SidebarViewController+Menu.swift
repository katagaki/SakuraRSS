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
        if let markAllRead = markAllReadAction(for: location) {
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
            let deleteTitle = String(localized: "ListMenu.Delete", table: "Lists")
            menu.addItem(ActionMenuItem(deleteTitle, symbolName: "trash") { [weak self] in
                self?.confirmDeleting(list)
            })
        default:
            break
        }
    }

    private func markAllReadAction(for location: BrowserLocation) -> (@MainActor () -> Void)? {
        let feedManager = feedManager
        switch location {
        case .allContent:
            return { feedManager.markAllRead() }
        case .feedSection(let section):
            return { feedManager.markAllRead(for: section) }
        case .feed(let feedID):
            guard let feed = feedManager.feedsByID[feedID] else { return nil }
            return { feedManager.markAllRead(feed: feed) }
        case .list(let listID):
            guard let list = feedManager.lists.first(where: { $0.id == listID }) else { return nil }
            return { feedManager.markAllRead(for: list) }
        default:
            return nil
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
