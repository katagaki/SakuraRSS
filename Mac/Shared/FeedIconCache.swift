import AppKit
import Hanami

/// Feed icons for list rows, looked up once per feed.
final class FeedIconCache {

    static let shared = FeedIconCache()

    private var icons: [Int64: NSImage] = [:]
    private var loading: Set<Int64> = []
    private var waiting: [Int64: [(NSImage?) -> Void]] = [:]

    func icon(for feed: Feed, completion: @escaping (NSImage?) -> Void) {
        if let icon = icons[feed.id] {
            completion(icon)
            return
        }
        waiting[feed.id, default: []].append(completion)
        guard loading.insert(feed.id).inserted else { return }
        Task {
            let icon = await Iconography.shared.icon(for: feed)
                ?? InitialsAvatar.renderToImage(name: feed.title, size: 64)
            icons[feed.id] = icon
            loading.remove(feed.id)
            (waiting.removeValue(forKey: feed.id) ?? []).forEach { $0(icon) }
        }
    }
}
