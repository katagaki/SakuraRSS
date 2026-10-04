import AppKit
import Hanami

extension ContentListViewController {

    func handle(_ shortcut: ContentListTableView.Shortcut) {
        switch shortcut {
        case .next:
            selectRow(offsetBy: 1)
        case .previous:
            selectRow(offsetBy: -1)
        case .toggleRead:
            if let selectedArticle { feedManager.toggleRead(selectedArticle) }
        case .toggleBookmark:
            if let selectedArticle { feedManager.toggleBookmark(selectedArticle) }
        case .openInBrowser:
            if let url = selectedArticle.flatMap({ URL(string: $0.url) }) { NSWorkspace.shared.open(url) }
        case .open:
            openSelectedFullWidth()
        }
    }

    @objc func openSelectedFullWidth() {
        let row = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
        guard articles.indices.contains(row) else { return }
        onOpenFullWidth?(.article(articles[row].id))
    }

    private func selectRow(offsetBy offset: Int) {
        guard !articles.isEmpty else { return }
        let current = tableView.selectedRow
        let next = current < 0 ? 0 : min(max(current + offset, 0), articles.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }
}
