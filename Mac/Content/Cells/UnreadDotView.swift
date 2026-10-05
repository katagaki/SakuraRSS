import AppKit

final class UnreadDotView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 4
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 8),
            heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isUnread = false {
        didSet {
            layer?.backgroundColor = isUnread ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        }
    }
}
