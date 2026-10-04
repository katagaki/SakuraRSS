import AppKit
import Hanami

/// Feed icons shaped for sidebar rows. They're kept across reloads, since the
/// tree is rebuilt whenever an unread count changes.
@MainActor
enum SidebarFeedIcons {

    static let side: CGFloat = 16
    private static var cache: [String: NSImage] = [:]

    static func cachedIcon(for feed: Feed, revision: Int) -> NSImage? {
        cache[key(for: feed, revision: revision)]
    }

    static func loadIcon(for feed: Feed, revision: Int) async -> NSImage? {
        let key = key(for: feed, revision: revision)
        if let cached = cache[key] {
            return cached
        }
        let source = await Iconography.shared.icon(for: feed)
            ?? InitialsAvatar.renderToImage(name: feed.title, size: side * 2)
        guard let source else { return nil }
        let icon = shaped(source, isCircle: feed.isCircleIcon)
        cache[key] = icon
        return icon
    }

    private static func key(for feed: Feed, revision: Int) -> String {
        "\(feed.id).\(revision)"
    }

    private static func shaped(_ source: NSImage, isCircle: Bool) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let clip = isCircle
                ? NSBezierPath(ovalIn: rect)
                : NSBezierPath(roundedRect: rect, xRadius: side * 0.22, yRadius: side * 0.22)
            clip.addClip()
            let sourceSize = source.size
            guard sourceSize.width > 0, sourceSize.height > 0 else { return true }
            let scale = max(rect.width / sourceSize.width, rect.height / sourceSize.height)
            let drawSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
            let origin = NSPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
            source.draw(in: NSRect(origin: origin, size: drawSize))
            return true
        }
    }
}
