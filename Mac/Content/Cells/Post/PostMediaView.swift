import AppKit

/// A row's image, filling a rounded, hairline-bordered frame, with a play
/// badge over video and podcast content.
final class PostMediaView: NSView {

    private let imageLayer = CALayer()
    private let playBadge = NSVisualEffectView()
    private var representedURL: String?
    private var imageSize: CGSize?
    private var centersImage = false

    init(cornerRadius: CGFloat, badgeSize: CGFloat, badgePointSize: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        imageLayer.contentsGravity = .resize
        layer?.addSublayer(imageLayer)
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        let playImage = NSImageView(image: NSImage(
            systemSymbolName: "play.fill", accessibilityDescription: nil
        ) ?? NSImage())
        playImage.symbolConfiguration = .init(pointSize: badgePointSize, weight: .regular)
        playImage.contentTintColor = .labelColor
        playBadge.material = .hudWindow
        playBadge.blendingMode = .withinWindow
        playBadge.state = .active
        playBadge.wantsLayer = true
        playBadge.layer?.cornerRadius = badgeSize / 2
        playBadge.addSubview(playImage)
        addSubview(playBadge)
        for view in [playImage, playBadge] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            playBadge.widthAnchor.constraint(equalToConstant: badgeSize),
            playBadge.heightAnchor.constraint(equalToConstant: badgeSize),
            playBadge.centerXAnchor.constraint(equalTo: centerXAnchor),
            playBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            playImage.centerXAnchor.constraint(equalTo: playBadge.centerXAnchor),
            playImage.centerYAnchor.constraint(equalTo: playBadge.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.2).cgColor
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = filledImageFrame
        CATransaction.commit()
    }

    /// Fills the frame like iOS's `scaledToFill()`, pinned to the top for wide
    /// images and to the leading edge for tall ones.
    private var filledImageFrame: CGRect {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let isTall = imageSize.height > imageSize.width
        let xPosition = centersImage || !isTall ? (bounds.width - size.width) / 2 : 0
        let yPosition = centersImage || isTall ? (bounds.height - size.height) / 2 : bounds.height - size.height
        return CGRect(origin: CGPoint(x: xPosition, y: yPosition), size: size)
    }

    private func display(_ image: NSImage?) {
        imageLayer.contents = image
        imageSize = image?.size
        needsLayout = true
    }

    func configure(urlString: String, showsPlayBadge: Bool, centersImage: Bool) {
        representedURL = urlString
        self.centersImage = centersImage
        playBadge.isHidden = !showsPlayBadge
        if let cached = RemoteImageCache.shared.cachedImage(for: urlString) {
            display(cached)
            return
        }
        display(nil)
        RemoteImageCache.shared.image(for: urlString) { [weak self] image in
            guard let self, self.representedURL == urlString else { return }
            self.display(image)
        }
    }
}
