import AppKit
import Hanami

final class ContentCompactCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentCompactCell")

    private let unreadDot = UnreadDotView()
    private let titleField = NSTextField(labelWithString: "")
    private let dateField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        titleField.lineBreakMode = .byTruncatingTail
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        dateField.font = .preferredFont(forTextStyle: .caption1)
        dateField.textColor = .secondaryLabelColor
        dateField.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [unreadDot, titleField, dateField])
        stack.spacing = 8
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, isRead: Bool) {
        unreadDot.isUnread = !isRead
        titleField.stringValue = article.displayTitle
        titleField.textColor = isRead ? .secondaryLabelColor : .labelColor
        dateField.stringValue = article.publishedDate?.formatted(.relative(presentation: .numeric)) ?? ""
    }
}
