import AppKit

final class SuggestionCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("SuggestionCell")

    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        iconView.contentTintColor = .secondaryLabelColor
        titleField.lineBreakMode = .byTruncatingTail
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.font = .preferredFont(forTextStyle: .caption1)
        subtitleField.textColor = .secondaryLabelColor
        for field in [titleField, subtitleField] {
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let textStack = NSStackView(views: [titleField, subtitleField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        let stack = NSStackView(views: [iconView, textStack])
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(_ suggestion: AddressSuggestion) {
        titleField.stringValue = suggestion.title
        subtitleField.stringValue = suggestion.subtitle ?? ""
        subtitleField.isHidden = suggestion.subtitle?.isEmpty ?? true
        iconView.image = NSImage(systemSymbolName: suggestion.symbolName, accessibilityDescription: nil)
    }
}
