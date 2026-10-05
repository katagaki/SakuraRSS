import AppKit

/// A `PostActionButton` on a filled circle, as the Compact Feed style's
/// quick actions are drawn on iOS.
final class PostCircleActionView: NSView {

    let button: PostActionButton

    init(symbolName: String) {
        button = PostActionButton(symbolName: symbolName, pointSize: 14)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 18
        button.contentTintColor = .labelColor
        for view in [self, button] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        addSubview(button)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 36),
            heightAnchor.constraint(equalToConstant: 36),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.15).cgColor
    }
}
