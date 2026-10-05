import AppKit
import Hanami

/// The Feed style: content laid out like a social post, matching iOS's
/// `FeedArticleRow`.
final class ContentPostCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentPostCell")

    private let avatarView = PostAvatarView(size: 40, cornerRadius: 8)
    private let headerView = PostHeaderView(
        textStyle: .subheadline, nameWeight: .bold, leadingView: nil, trailingView: nil
    )
    private let bodyField = NSTextField(wrappingLabelWithString: "")
    private let mediaView = PostMediaView(cornerRadius: 12, badgeSize: 60, badgePointSize: 22)
    private let openButton = PostActionButton(symbolName: "arrow.up.forward.square", pointSize: 13)
    private let copyButton = PostActionButton(symbolName: "square.on.square", pointSize: 13)
    private let readButton = PostActionButton(symbolName: "envelope.open", pointSize: 13)
    private let bookmarkButton = PostActionButton(symbolName: "bookmark", pointSize: 13)
    private let shareButton = PostActionButton(symbolName: "square.and.arrow.up", pointSize: 13)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        bodyField.font = .preferredFont(forTextStyle: .subheadline)
        bodyField.lineBreakMode = .byWordWrapping
        bodyField.cell?.truncatesLastVisibleLine = true
        bodyField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let buttons = [openButton, copyButton, readButton, bookmarkButton, shareButton]
        for button in buttons {
            button.contentTintColor = .secondaryLabelColor
        }
        let actionBar = NSStackView(views: buttons)
        actionBar.distribution = .equalSpacing
        let column = NSStackView(views: [headerView, bodyField, mediaView, actionBar])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6
        column.setCustomSpacing(10, after: bodyField)
        column.setCustomSpacing(10, after: mediaView)
        for view in [avatarView, column] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            column.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            headerView.widthAnchor.constraint(equalTo: column.widthAnchor),
            mediaView.widthAnchor.constraint(equalTo: column.widthAnchor),
            mediaView.heightAnchor.constraint(equalToConstant: 200),
            actionBar.widthAnchor.constraint(equalTo: column.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feed: Feed?, isRead: Bool, isBookmarked: Bool, actions: PostCellActions) {
        avatarView.configure(feed: feed)
        headerView.configure(article: article, feed: feed, isRead: isRead)
        let summary = article.hasMeaningfulSummary ? article.summary.map(SummaryPreview.text(for:)) ?? "" : ""
        bodyField.stringValue = (summary.isEmpty ? article.displayTitle : summary)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let showsFullText = feed.map { $0.isXFeed || $0.isInstagramFeed } ?? false
        bodyField.maximumNumberOfLines = showsFullText ? 0 : 3
        if let imageURL = article.imageURL {
            mediaView.isHidden = false
            let isMediaFeed = feed.map { $0.isVideoFeed || $0.isPodcast } ?? false
            mediaView.configure(
                urlString: imageURL,
                showsPlayBadge: isMediaFeed || article.hasXVideoThumbnail,
                centersImage: feed.map { CenteredImageDomains.shouldCenterImage(feedDomain: $0.domain) } ?? false
            )
        } else {
            mediaView.isHidden = true
        }
        readButton.setSymbol(isRead ? "envelope" : "envelope.open")
        bookmarkButton.setSymbol(isBookmarked ? "bookmark.fill" : "bookmark")
        openButton.isEnabled = article.hasLink
        openButton.handler = { _ in actions.open() }
        copyButton.handler = { _ in actions.copyLink() }
        readButton.handler = { _ in actions.toggleRead() }
        bookmarkButton.handler = { _ in actions.toggleBookmark() }
        shareButton.handler = actions.share
    }
}
