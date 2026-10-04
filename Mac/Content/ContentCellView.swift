import AppKit
import Hanami

final class ContentCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentCell")

    private let unreadDot = NSView()
    private let titleField = NSTextField(wrappingLabelWithString: "")
    private let detailField = NSTextField(labelWithString: "")
    private let summaryField = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        unreadDot.wantsLayer = true
        unreadDot.layer?.cornerRadius = 4
        titleField.maximumNumberOfLines = 3
        detailField.font = .preferredFont(forTextStyle: .caption1)
        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byTruncatingTail
        summaryField.font = .preferredFont(forTextStyle: .subheadline)
        summaryField.textColor = .secondaryLabelColor
        summaryField.maximumNumberOfLines = 2
        for field in [titleField, detailField, summaryField] {
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let textStack = NSStackView(views: [detailField, titleField, summaryField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        for view in [unreadDot, textStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            unreadDot.widthAnchor.constraint(equalToConstant: 8),
            unreadDot.heightAnchor.constraint(equalToConstant: 8),
            unreadDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            unreadDot.centerYAnchor.constraint(equalTo: titleField.centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: unreadDot.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feedTitle: String?, isRead: Bool) {
        titleField.stringValue = article.displayTitle
        titleField.font = .systemFont(ofSize: NSFont.systemFontSize, weight: isRead ? .regular : .semibold)
        titleField.textColor = isRead ? .secondaryLabelColor : .labelColor
        let date = article.publishedDate?.formatted(.relative(presentation: .named))
        detailField.stringValue = [feedTitle, date].compactMap { $0 }.joined(separator: " · ")
        let summary = article.hasMeaningfulSummary ? article.summary.map(SummaryPreview.text(for:)) ?? "" : ""
        summaryField.stringValue = summary
        summaryField.isHidden = summary.isEmpty
        unreadDot.layer?.backgroundColor = isRead ? NSColor.clear.cgColor : NSColor.controlAccentColor.cgColor
    }
}
