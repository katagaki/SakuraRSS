import AppKit
import Hanami

/// The Feed and Compact Feed styles: content laid out like a social post,
/// with the feed's icon, the post's text and, unless compact, its image.
final class ContentPostCellView: NSTableCellView {

    static let identifier = NSUserInterfaceItemIdentifier("ContentPostCell")

    private let iconView = NSImageView()
    private let headerField = NSTextField(labelWithString: "")
    private let bodyField = NSTextField(wrappingLabelWithString: "")
    private let mediaView = NSImageView()
    private var mediaHeight: NSLayoutConstraint!
    private var representedArticleID: Int64?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = Self.identifier
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 8
        iconView.layer?.masksToBounds = true
        iconView.imageScaling = .scaleProportionallyUpOrDown
        headerField.font = .preferredFont(forTextStyle: .caption1)
        headerField.textColor = .secondaryLabelColor
        headerField.lineBreakMode = .byTruncatingTail
        bodyField.maximumNumberOfLines = 8
        mediaView.wantsLayer = true
        mediaView.layer?.cornerRadius = 10
        mediaView.layer?.masksToBounds = true
        mediaView.imageScaling = .scaleProportionallyUpOrDown
        for field in [headerField, bodyField] {
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let textStack = NSStackView(views: [headerField, bodyField, mediaView])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        for view in [iconView, textStack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        mediaHeight = mediaView.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 34),
            iconView.heightAnchor.constraint(equalToConstant: 34),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            mediaView.widthAnchor.constraint(equalTo: textStack.widthAnchor),
            mediaHeight
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(article: Article, feed: Feed?, isRead: Bool, showsMedia: Bool) {
        representedArticleID = article.id
        let date = article.publishedDate?.formatted(.relative(presentation: .numeric))
        headerField.stringValue = [feed?.title, date].compactMap { $0 }.joined(separator: " · ")
        let body = article.hasMeaningfulSummary ? article.summary.map(SummaryPreview.text(for:)) ?? "" : ""
        bodyField.stringValue = body.isEmpty ? article.displayTitle : body
        bodyField.textColor = isRead ? .secondaryLabelColor : .labelColor
        iconView.image = nil
        if let feed {
            FeedIconCache.shared.icon(for: feed) { [weak self] icon in
                guard self?.representedArticleID == article.id else { return }
                self?.iconView.image = icon
            }
        }
        configureMedia(urlString: showsMedia ? article.imageURL : nil, articleID: article.id)
    }

    private func configureMedia(urlString: String?, articleID: Int64) {
        mediaView.image = nil
        guard let urlString else {
            mediaView.isHidden = true
            mediaHeight.constant = 0
            return
        }
        mediaView.isHidden = false
        mediaHeight.constant = 200
        if let cached = RemoteImageCache.shared.cachedImage(for: urlString) {
            mediaView.image = cached
            return
        }
        RemoteImageCache.shared.image(for: urlString) { [weak self] image in
            guard self?.representedArticleID == articleID else { return }
            self?.mediaView.image = image
        }
    }
}
