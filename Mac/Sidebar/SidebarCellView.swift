import AppKit

final class SidebarCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("SidebarCell")

    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let badgeField = NSTextField(labelWithString: "")

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

    func configure(title: String, symbolName: String, unreadCount: Int) {
        titleField.stringValue = title
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        iconView.contentTintColor = .controlAccentColor
        badgeField.stringValue = unreadCount > 0 ? unreadCount.formatted() : ""
        badgeField.isHidden = unreadCount == 0
    }
}
