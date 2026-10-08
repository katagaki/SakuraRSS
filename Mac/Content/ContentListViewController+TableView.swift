import AppKit
import Hanami

extension ContentListViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        articles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let article = articles[row]
        let feed = feedManager.feedsByID[article.feedID]
        let isRead = feedManager.isRead(article)
        switch displayStyle {
        case .compact:
            let cell = reusableCell(ContentCompactCellView.identifier) { ContentCompactCellView() }
            cell.configure(article: article, isRead: isRead)
            return cell
        case .timeline:
            let cell = reusableCell(ContentTimelineCellView.identifier) { ContentTimelineCellView() }
            cell.configure(article: article, feedTitle: feed?.title, isRead: isRead)
            return cell
        case .feed, .feedSingle, .feedGrid:
            let cell = reusableCell(ContentPostCellView.identifier) { ContentPostCellView() }
            cell.configure(
                article: article, feed: feed, isRead: isRead,
                isBookmarked: feedManager.isBookmarked(article), actions: postActions(for: article)
            )
            return cell
        case .feedCompact:
            let cell = reusableCell(ContentCompactPostCellView.identifier) { ContentCompactPostCellView() }
            cell.configure(article: article, feed: feed, isRead: isRead, actions: postActions(for: article))
            return cell
        default:
            let cell = reusableCell(ContentCellView.identifier) { ContentCellView() }
            cell.configure(article: article, feedTitle: feed?.title, isRead: isRead)
            return cell
        }
    }

    private func reusableCell<Cell: NSView>(_ identifier: NSUserInterfaceItemIdentifier, make: () -> Cell) -> Cell {
        tableView.makeView(withIdentifier: identifier, owner: self) as? Cell ?? make()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let article = selectedArticle, article.id != reportedArticleID else { return }
        reportedArticleID = article.id
        if ContentOpening(article: article, feedManager: feedManager, context: location).marksRead {
            feedManager.markRead(article)
        }
        onSelectArticle?(article)
    }
}
