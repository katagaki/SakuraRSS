import AppKit

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
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Suggestion"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .inset
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(commitClickedRow)
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        let background = NSVisualEffectView()
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: background.topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -6)
        ])
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
        guard let window = field.window, !rows.isEmpty else {
            hide()
            return
        }
        let fieldFrame = window.convertToScreen(field.convert(field.bounds, to: nil))
        let height = min(440, CGFloat(rows.count) * 34 + 12)
        let width = max(fieldFrame.width, 440)
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
