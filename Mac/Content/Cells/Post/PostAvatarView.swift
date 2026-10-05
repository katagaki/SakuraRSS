import AppKit
import Hanami

/// A feed's icon, rounded or circular depending on the feed.
final class PostAvatarView: NSImageView {

    private let size: CGFloat
    private let cornerRadius: CGFloat
    private var representedFeedID: Int64?

    init(size: CGFloat, cornerRadius: CGFloat) {
        self.size = size
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        imageScaling = .scaleProportionallyUpOrDown
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(feed: Feed?) {
        representedFeedID = feed?.id
        image = nil
        layer?.cornerRadius = feed?.isCircleIcon == true ? size / 2 : cornerRadius
        guard let feed else { return }
        FeedIconCache.shared.icon(for: feed) { [weak self] icon in
            guard self?.representedFeedID == feed.id else { return }
            self?.image = icon
        }
    }
}
