import AppKit
import Hanami

final class ContentTimelineCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentTimelineCell")

    private let timeField = NSTextField(labelWithString: "")
    private let unreadDot = UnreadDotView()
    private let titleField = NSTextField(wrappingLabelWithString: "")
    private let feedField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        timeField.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        timeField.textColor = .secondaryLabelColor
        timeField.alignment = .right
        titleField.maximumNumberOfLines = 2
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        feedField.font = .preferredFont(forTextStyle: .caption1)
        feedField.textColor = .secondaryLabelColor
        feedField.lineBreakMode = .byTruncatingTail
        feedField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let textStack = NSStackView(views: [titleField, feedField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        for view in [timeField, unreadDot, textStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            timeField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            timeField.widthAnchor.constraint(equalToConstant: 42),
            timeField.firstBaselineAnchor.constraint(equalTo: titleField.firstBaselineAnchor),
            unreadDot.leadingAnchor.constraint(equalTo: timeField.trailingAnchor, constant: 8),
            unreadDot.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: unreadDot.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feedTitle: String?, isRead: Bool) {
        timeField.stringValue = article.publishedDate?.formatted(.dateTime.hour().minute()) ?? ""
        unreadDot.isUnread = !isRead
        titleField.stringValue = article.displayTitle
        titleField.textColor = isRead ? .secondaryLabelColor : .labelColor
        feedField.stringValue = feedTitle ?? ""
    }
}
