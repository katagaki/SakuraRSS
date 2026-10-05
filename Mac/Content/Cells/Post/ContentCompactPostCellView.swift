import AppKit
import Hanami

/// The Compact Feed style, matching iOS's `CompactFeedArticleRow`: a slim
/// header, the title beside a square thumbnail, and two quick actions.
final class ContentCompactPostCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentCompactPostCell")

    private let avatarView = PostAvatarView(size: 20, cornerRadius: 4)
    private let moreButton = PostActionButton(symbolName: "ellipsis", pointSize: 11)
    private lazy var headerView = PostHeaderView(
        textStyle: .footnote, nameWeight: .semibold, leadingView: avatarView, trailingView: moreButton
    )
    private let titleField = NSTextField(wrappingLabelWithString: "")
    private let thumbnailView = PostMediaView(cornerRadius: 10, badgeSize: 28, badgePointSize: 11)
    private let openAction = PostCircleActionView(symbolName: "arrow.up.forward.square")
    private var textMatchesThumbnailHeight: NSLayoutConstraint!
    private let readAction = PostCircleActionView(symbolName: "envelope.open")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        titleField.font = .preferredFont(forTextStyle: .subheadline)
        titleField.maximumNumberOfLines = 3
        titleField.lineBreakMode = .byWordWrapping
        titleField.cell?.truncatesLastVisibleLine = true
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        moreButton.contentTintColor = .labelColor
        let actionRow = NSStackView(views: [openAction, readAction])
        actionRow.spacing = 12
        let textColumn = NSStackView(views: [titleField, actionRow])
        textColumn.orientation = .vertical
        textColumn.alignment = .leading
        textColumn.distribution = .equalSpacing
        textColumn.spacing = 8
        let bodyRow = NSStackView(views: [textColumn, thumbnailView])
        bodyRow.alignment = .top
        bodyRow.spacing = 10
        let column = NSStackView(views: [headerView, bodyRow])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)
        textMatchesThumbnailHeight = textColumn.heightAnchor.constraint(
            greaterThanOrEqualTo: thumbnailView.heightAnchor
        )
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            headerView.widthAnchor.constraint(equalTo: column.widthAnchor),
            bodyRow.widthAnchor.constraint(equalTo: column.widthAnchor),
            textMatchesThumbnailHeight,
            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feed: Feed?, isRead: Bool, actions: PostCellActions) {
        avatarView.configure(feed: feed)
        headerView.configure(article: article, feed: feed, isRead: isRead)
        titleField.stringValue = article.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        textMatchesThumbnailHeight.isActive = article.imageURL != nil
        if let imageURL = article.imageURL {
            thumbnailView.isHidden = false
            let isMediaFeed = feed.map { $0.isVideoFeed || $0.isPodcast } ?? false
            thumbnailView.configure(
                urlString: imageURL,
                showsPlayBadge: isMediaFeed || article.hasXVideoThumbnail,
                centersImage: true
            )
        } else {
            thumbnailView.isHidden = true
        }
        readAction.button.setSymbol(isRead ? "envelope" : "envelope.open")
        openAction.button.isEnabled = article.hasLink
        openAction.button.handler = { _ in actions.open() }
        readAction.button.handler = { _ in actions.toggleRead() }
        moreButton.handler = actions.showMenu
    }
}
