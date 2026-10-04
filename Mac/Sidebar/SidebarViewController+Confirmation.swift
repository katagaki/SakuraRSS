import AppKit
import Hanami

/// The same confirmations iOS asks for before removing a feed or a list.
extension SidebarViewController {

    func confirmUnfollowing(_ feed: Feed) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "FeedMenu.Unfollow.Title", table: "Feeds")
        alert.informativeText = String(localized: "FeedMenu.Unfollow.Message.\(feed.title)", table: "Feeds")
        let confirmButton = alert.addButton(withTitle: String(localized: "FeedMenu.Unfollow.Confirm", table: "Feeds"))
        confirmButton.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Shared.Cancel"))
        present(alert) { [feedManager] in
            try? feedManager.deleteFeed(feed)
        }
    }

    func confirmDeleting(_ list: FeedList) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(localized: "ListMenu.Delete.Title", table: "Lists")
        alert.informativeText = String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists")
        let confirmButton = alert.addButton(withTitle: String(localized: "ListMenu.Delete.Confirm", table: "Lists"))
        confirmButton.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Shared.Cancel"))
        present(alert) { [feedManager] in
            feedManager.deleteList(list)
        }
    }

    private func present(_ alert: NSAlert, onConfirm: @escaping @MainActor () -> Void) {
        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            MainActor.assumeIsolated {
                onConfirm()
            }
        }
    }
}
