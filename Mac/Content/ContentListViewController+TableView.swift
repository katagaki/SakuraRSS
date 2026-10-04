import AppKit
import Hanami

extension ContentListViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        articles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: ContentCellView.identifier, owner: self) as? ContentCellView
            ?? ContentCellView()
        let article = articles[row]
        cell.configure(
            article: article,
            feedTitle: feedManager.feedsByID[article.feedID]?.title,
            isRead: feedManager.isRead(article)
        )
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let article = selectedArticle, article.id != reportedArticleID else { return }
        reportedArticleID = article.id
        feedManager.markRead(article)
        onSelectArticle?(article)
    }
}
