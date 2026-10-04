import AppKit

extension ContentListViewController: NSMenuDelegate {

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard articles.indices.contains(tableView.clickedRow) else { return }
        let builder = ContentMenuBuilder(feedManager: feedManager) { [weak self] location in
            self?.onOpenInNewTab?(location)
        }
        for item in builder.items(for: articles[tableView.clickedRow]) {
            menu.addItem(item)
        }
    }
}
