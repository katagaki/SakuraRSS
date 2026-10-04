import AppKit

extension ContentListViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard articles.indices.contains(tableView.clickedRow) else { return }
        var builder = ContentMenuBuilder(feedManager: feedManager) { [weak self] location in
            self?.onOpenInNewTab?(location)
        }
        builder.moveToFolder = { [weak self] article in
            guard let self else { return }
            self.presentSwiftUISheet(MoveToFolderSheet(article: article), feedManager: self.feedManager)
        }
        for item in builder.items(for: articles[tableView.clickedRow]) {
            menu.addItem(item)
        }
        if let markAllRead = location?.markAllReadAction(in: feedManager) {
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem(
                String(localized: "MarkAllRead", table: "Articles"),
                symbolName: "checkmark.circle",
                handler: markAllRead
            ))
        }
    }
}
