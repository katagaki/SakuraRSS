import AppKit
import Hanami

extension ContentListViewController {

    func postActions(for article: Article) -> PostCellActions {
        let feedManager = feedManager
        let url = URL(string: article.url)
        return PostCellActions(
            open: {
                guard let url else { return }
                feedManager.markRead(article)
                NSWorkspace.shared.open(url)
            },
            copyLink: {
                guard let url else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([url as NSURL])
            },
            toggleRead: { feedManager.toggleRead(article) },
            toggleBookmark: { feedManager.toggleBookmark(article) },
            share: { sourceView in
                guard let url else { return }
                NSSharingServicePicker(items: [url])
                    .show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .minY)
            },
            showMenu: { [weak self] sourceView in
                self?.showMenu(for: article, from: sourceView)
            }
        )
    }

    private func showMenu(for article: Article, from sourceView: NSView) {
        let menu = NSMenu()
        for item in contentMenuBuilder.items(for: article) {
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sourceView.bounds.maxY), in: sourceView)
    }
}
