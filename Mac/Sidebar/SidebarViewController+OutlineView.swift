import AppKit

extension SidebarViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? SidebarNode)?.children.count ?? nodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? SidebarNode)?.children[index] ?? nodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? SidebarNode)?.children.isEmpty ?? true)
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? SidebarNode)?.isGroup ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SidebarNode)?.location != nil
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        (item as? SidebarNode)?.identifier
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        guard let identifier = object as? String else { return nil }
        return node(withIdentifier: identifier)
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? SidebarNode else { return nil }
        switch node.kind {
        case .group(let title):
            let field = NSTextField(labelWithString: title)
            field.font = .preferredFont(forTextStyle: .subheadline)
            field.textColor = .secondaryLabelColor
            return field
        case .location(_, let title, let symbolName, let unreadCount):
            let cell = outlineView.makeView(withIdentifier: SidebarCellView.identifier, owner: self) as? SidebarCellView
                ?? SidebarCellView()
            cell.configure(title: title, symbolName: symbolName, unreadCount: unreadCount)
            return cell
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isApplyingSelection,
              let node = outlineView.item(atRow: outlineView.selectedRow) as? SidebarNode,
              let location = node.location else { return }
        onSelectLocation?(location)
    }
}
