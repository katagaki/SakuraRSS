import AppKit
import Hanami
import SwiftUI

/// The list that drops down from the address field. A child panel that never
/// takes key status, so typing stays in the field while it's open.
final class SuggestionsPanelController: NSObject {

    enum Row {
        case header(String)
        case suggestion(AddressSuggestion)
    }

    private let panel: NSPanel
    let tableView = NSTableView()
    var rows: [Row] = []
    var onCommit: ((AddressSuggestion) -> Void)?
    private let tableScrollView = NSScrollView()
    private let gridScrollView = NSScrollView()

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.isFloatingPanel = true
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.becomesKeyOnlyIfNeeded = true
        // Editing ends when the window resigns key, which closes the panel.
        panel.hidesOnDeactivate = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Suggestion"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .inset
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(commitClickedRow)
        tableScrollView.documentView = tableView
        tableScrollView.drawsBackground = false
        tableScrollView.hasVerticalScroller = true
        gridScrollView.drawsBackground = false
        gridScrollView.hasVerticalScroller = true
        gridScrollView.isHidden = true
        for scrollView in [tableScrollView, gridScrollView] {
            scrollView.automaticallyAdjustsContentInsets = false
            scrollView.contentInsets = NSEdgeInsetsZero
        }
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        for scrollView in [tableScrollView, gridScrollView] {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            background.addSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: background.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor)
            ])
        }
        panel.contentView = background
    }

    var isVisible: Bool { panel.isVisible }

    func owns(_ window: NSWindow?) -> Bool {
        window === panel
    }

    func show(_ suggestions: [AddressSuggestion], below field: NSView) {
        rows = Self.rows(for: suggestions)
        tableView.reloadData()
        selectFirstSuggestion()
        tableScrollView.isHidden = false
        gridScrollView.isHidden = true
        guard !rows.isEmpty else {
            hide()
            return
        }
        present(below: field, contentHeight: tableView.rect(ofRow: rows.count - 1).maxY)
    }

    /// The Following grid, shown in place of suggestions before anything is
    /// typed.
    func showFollowingGrid(feedManager: FeedManager, below field: NSView, onOpen: @escaping (BrowserLocation) -> Void) {
        rows = []
        tableView.reloadData()
        guard !feedManager.feeds.isEmpty else {
            hide()
            return
        }
        let grid = AddressFollowingGrid(feedManager: feedManager, onOpen: onOpen)
        let gridView = NSHostingView(rootView: grid)
        gridScrollView.documentView = gridView
        tableScrollView.isHidden = true
        gridScrollView.isHidden = false
        let width = panelWidth(below: field)
        let contentHeight = NSHostingController(rootView: grid)
            .sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
        gridView.frame = NSRect(x: 0, y: 0, width: width, height: contentHeight)
        present(below: field, contentHeight: contentHeight)
    }

    private func panelWidth(below field: NSView) -> CGFloat {
        max(field.bounds.width, 440)
    }

    private func present(below field: NSView, contentHeight: CGFloat) {
        guard let window = field.window else { return }
        let fieldFrame = window.convertToScreen(field.convert(field.bounds, to: nil))
        let height = min(480, contentHeight)
        let width = panelWidth(below: field)
        let frame = NSRect(
            x: fieldFrame.midX - width / 2,
            y: fieldFrame.minY - height - 6,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true)
        if panel.parent == nil {
            window.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    func hide() {
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    func moveSelection(by offset: Int) {
        let selectable = rows.indices.filter { if case .suggestion = rows[$0] { true } else { false } }
        guard !selectable.isEmpty else { return }
        let current = selectable.firstIndex(of: tableView.selectedRow) ?? -1
        let next = selectable[max(0, min(selectable.count - 1, current + offset))]
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    var selectedSuggestion: AddressSuggestion? {
        guard rows.indices.contains(tableView.selectedRow),
              case .suggestion(let suggestion) = rows[tableView.selectedRow] else { return nil }
        return suggestion
    }

    private func selectFirstSuggestion() {
        tableView.deselectAll(nil)
        moveSelection(by: 1)
    }

    @objc private func commitClickedRow() {
        guard rows.indices.contains(tableView.clickedRow),
              case .suggestion(let suggestion) = rows[tableView.clickedRow] else { return }
        onCommit?(suggestion)
    }

    private static func rows(for suggestions: [AddressSuggestion]) -> [Row] {
        AddressSuggestion.Section.allCases.flatMap { section -> [Row] in
            let matches = suggestions.filter { $0.section == section }
            guard !matches.isEmpty else { return [] }
            return [.header(section.title)] + matches.map(Row.suggestion)
        }
    }
}
