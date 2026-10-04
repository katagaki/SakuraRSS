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

    func configure(title: String, symbolName: String, unreadCount: Int, feed: Feed? = nil, iconRevision: Int = 0) {
        titleField.stringValue = title
        iconTask?.cancel()
        if let feed {
            showIcon(for: feed, revision: iconRevision)
        } else {
            iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            iconView.contentTintColor = .controlAccentColor
        }
        badgeField.stringValue = unreadCount > 0 ? unreadCount.formatted() : ""
        badgeField.isHidden = unreadCount == 0
    }

    private func showIcon(for feed: Feed, revision: Int) {
        iconView.contentTintColor = nil
        if let cached = SidebarFeedIcons.cachedIcon(for: feed, revision: revision) {
            iconView.image = cached
            return
        }
        iconView.image = nil
        iconTask = Task { [weak self] in
            let icon = await SidebarFeedIcons.loadIcon(for: feed, revision: revision)
            guard !Task.isCancelled else { return }
            self?.iconView.image = icon
        }
    }
}
