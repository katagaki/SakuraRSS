import AppKit
import Hanami

/// The feed name, timestamp and unread dot along the top of a Feed row.
final class PostHeaderView: NSStackView {

    private let nameField = NSTextField(labelWithString: "")
    private let separatorField = NSTextField(labelWithString: "·")
    private let timeField = NSTextField(labelWithString: "")
    private let unreadDot = UnreadDotView()

    init(textStyle: NSFont.TextStyle, nameWeight: NSFont.Weight, leadingView: NSView?, trailingView: NSView?) {
        super.init(frame: .zero)
        let font = NSFont.preferredFont(forTextStyle: textStyle)
        nameField.font = .systemFont(ofSize: font.pointSize, weight: nameWeight)
        nameField.lineBreakMode = .byTruncatingTail
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for field in [separatorField, timeField] {
            field.font = font
            field.textColor = .secondaryLabelColor
            field.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        }
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let views = [leadingView, nameField, separatorField, timeField, spacer, unreadDot, trailingView]
        setViews(views.compactMap { $0 }, in: .leading)
        orientation = .horizontal
        alignment = .centerY
        spacing = 4
        if let leadingView {
            setCustomSpacing(6, after: leadingView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feed: Feed?, isRead: Bool) {
        nameField.stringValue = feed?.title ?? ""
        nameField.isHidden = feed == nil
        let time = article.publishedDate.map(PostRelativeTime.text(for:))
        timeField.stringValue = time ?? ""
        timeField.isHidden = time == nil
        separatorField.isHidden = time == nil || feed == nil
        unreadDot.isUnread = !isRead
        unreadDot.isHidden = isRead
    }
}
