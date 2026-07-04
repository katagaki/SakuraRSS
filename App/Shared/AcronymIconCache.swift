import Hanami
import UIKit

/// Decoded acronym icons keyed by feed ID, so rows share one UIImage instance
/// and the icon metrics cached on it are computed once per feed rather than
/// per row. Entries are revalidated by byte count so edited icons refresh.
nonisolated final class AcronymIconCache: @unchecked Sendable {

    static let shared = AcronymIconCache()

    private final class Entry {
        let image: UIImage
        let byteCount: Int
        init(image: UIImage, byteCount: Int) {
            self.image = image
            self.byteCount = byteCount
        }
    }

    private let cache = NSCache<NSNumber, Entry>()

    private init() {
        cache.countLimit = 512
    }

    func icon(for feed: Feed) -> UIImage? {
        guard let data = feed.acronymIcon else { return nil }
        let key = NSNumber(value: feed.id)
        if let entry = cache.object(forKey: key), entry.byteCount == data.count {
            return entry.image
        }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(Entry(image: image, byteCount: data.count), forKey: key)
        return image
    }
}
