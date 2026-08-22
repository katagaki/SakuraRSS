import Foundation

/// Memoizes the derived values that hot list paths read thousands of times per
/// query. Keyed purely on the stored properties they are computed from, so the
/// results stay consistent with `Feed`'s value semantics.
nonisolated final class FeedDerivedValues: @unchecked Sendable {

    static let shared = FeedDerivedValues()

    private static let entryLimit = 4096

    private let lock = NSLock()
    private var domains: [String: String] = [:]
    private var sections: [String: FeedSection] = [:]

    func domain(siteURL: String, fetchURL: String) -> String {
        let key = "\(siteURL)\n\(fetchURL)"
        lock.lock()
        if let cached = domains[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let value = URL(string: siteURL)?.host ?? URL(string: fetchURL)?.host ?? ""
        lock.lock()
        if domains.count >= Self.entryLimit {
            domains.removeAll(keepingCapacity: true)
        }
        domains[key] = value
        lock.unlock()
        return value
    }

    func section(for feed: Feed, compute: (Feed) -> FeedSection) -> FeedSection {
        let fediverseKey = feed.isFediverse.map { $0 ? "1" : "0" } ?? "-"
        let key = "\(feed.isPodcast ? 1 : 0)\n\(fediverseKey)\n\(feed.url)\n\(feed.siteURL)"
        lock.lock()
        if let cached = sections[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let value = compute(feed)
        lock.lock()
        if sections.count >= Self.entryLimit {
            sections.removeAll(keepingCapacity: true)
        }
        sections[key] = value
        lock.unlock()
        return value
    }
}
