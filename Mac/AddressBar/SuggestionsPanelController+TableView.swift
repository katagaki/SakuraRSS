import AppKit

extension SuggestionsPanelController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .header = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .suggestion = rows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if case .header = rows[row] { return 22 }
        return 36
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case .header(let title):
            let field = NSTextField(labelWithString: title)
            field.font = .preferredFont(forTextStyle: .caption1)
            field.textColor = .secondaryLabelColor
            return field
        case .suggestion(let suggestion):
            let cell = tableView.makeView(withIdentifier: SuggestionCellView.identifier, owner: self)
                as? SuggestionCellView ?? SuggestionCellView()
            cell.configure(suggestion)
            return cell
        }
    }
}
