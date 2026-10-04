import AppKit
import Hanami

final class SidebarCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("SidebarCell")

    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let badgeField = NSTextField(labelWithString: "")
    private var iconTask: Task<Void, Never>?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        imageView = iconView
        textField = titleField
        titleField.lineBreakMode = .byTruncatingTail
        badgeField.textColor = .secondaryLabelColor
        badgeField.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        badgeField.setContentHuggingPriority(.required, for: .horizontal)
        badgeField.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [iconView, titleField, badgeField])
        stack.spacing = 6
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String, icon: SidebarIcons.Source, unreadCount: Int) {
        titleField.stringValue = title
        iconTask?.cancel()
        showIcon(icon)
        badgeField.stringValue = unreadCount > 0 ? unreadCount.formatted() : ""
        badgeField.isHidden = unreadCount == 0
    }

    private func showIcon(_ source: SidebarIcons.Source) {
        if let cached = SidebarIcons.cachedIcon(for: source) {
            iconView.contentTintColor = nil
            iconView.image = cached
            return
        }
        switch source {
        case .symbol(let symbolName), .section(_, let symbolName):
            iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            iconView.contentTintColor = .controlAccentColor
        case .feed:
            iconView.image = nil
        }
        iconTask = Task { [weak self] in
            guard let icon = await SidebarIcons.loadIcon(for: source), !Task.isCancelled else { return }
            self?.iconView.contentTintColor = nil
            self?.iconView.image = icon
        }
    }
}
