import AppKit
import Hanami

final class FeedTitlesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let feedManager: FeedManager
    private let tableView = NSTableView()

    init(feedManager: FeedManager) {
        self.feedManager = feedManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Title"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        view = scrollView
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        feedManager.feeds.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(labelWithString: feedManager.feeds[row].title)
    }
}
