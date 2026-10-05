import AppKit
import Hanami

/// Feed and service icons shaped for sidebar rows. They're kept across
/// reloads, since the tree is rebuilt whenever an unread count changes.
@MainActor
enum SidebarIcons {

    enum Source {
        case symbol(String)
        case feed(Feed, revision: Int)
        case section(FeedSection, fallbackSymbol: String)
    }

    static let side: CGFloat = 16
    private static var cache: [String: NSImage] = [:]

    static func cachedIcon(for source: Source) -> NSImage? {
        cacheKey(for: source).flatMap { cache[$0] }
    }

    static func loadIcon(for source: Source) async -> NSImage? {
        guard let key = cacheKey(for: source) else { return nil }
        if let cached = cache[key] {
            return cached
        }
        let icon: NSImage?
        switch source {
        case .symbol:
            icon = nil
        case .feed(let feed, _):
            let image = await Iconography.shared.icon(for: feed)
                ?? InitialsAvatar.renderToImage(name: feed.title, size: side * 2)
            icon = image.map { shaped($0, isCircle: feed.isCircleIcon) }
        case .section(let section, _):
            icon = await Iconography.shared.icon(for: section).map { shaped($0, isCircle: false) }
        }
        cache[key] = icon
        return icon
    }

    private static func cacheKey(for source: Source) -> String? {
        switch source {
        case .symbol: nil
        case .feed(let feed, let revision): "feed.\(feed.id).\(revision)"
        case .section(let section, _): "section.\(section.rawValue)"
        }
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
