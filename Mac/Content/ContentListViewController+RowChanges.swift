import AppKit
import Hanami

extension ContentListViewController {

    /// Inserts and removes only the rows that changed. New content arriving
    /// above the rows on screen doesn't push them down: the first visible row
    /// stays where it was, unless the list was scrolled to the top.
    func applyRowChanges(to reloaded: [Article]) {
        let difference = reloaded.map(\.id).difference(from: articles.map(\.id))
        guard !difference.isEmpty else {
            articles = reloaded
            return
        }
        let anchor = visibleAnchor()
        var removals = IndexSet()
        var insertions = IndexSet()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removals.insert(offset)
            case .insert(let offset, _, _): insertions.insert(offset)
            }
        }
        articles = reloaded
        tableView.beginUpdates()
        tableView.removeRows(at: removals, withAnimation: [])
        tableView.insertRows(at: insertions, withAnimation: [])
        tableView.endUpdates()
        restore(anchor)
    }

    private struct VisibleAnchor {
        let articleID: Int64
        let offset: CGFloat
    }

    private func visibleAnchor() -> VisibleAnchor? {
        let visibleRect = tableView.visibleRect
        let firstRow = tableView.rows(in: visibleRect).location
        guard firstRow > 0 || visibleRect.minY > 0, articles.indices.contains(firstRow) else { return nil }
        return VisibleAnchor(
            articleID: articles[firstRow].id,
            offset: tableView.rect(ofRow: firstRow).minY - visibleRect.minY
        )
    }

    private func restore(_ anchor: VisibleAnchor?) {
        guard let anchor, let row = articles.firstIndex(where: { $0.id == anchor.articleID }),
              let clipView = tableView.enclosingScrollView?.contentView else { return }
        let originY = max(tableView.rect(ofRow: row).minY - anchor.offset, 0)
        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: originY))
        tableView.enclosingScrollView?.reflectScrolledClipView(clipView)
    }
}
