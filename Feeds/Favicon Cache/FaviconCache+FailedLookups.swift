import Foundation

extension FaviconCache {

    /// How long a failed favicon lookup is remembered before the host is
    /// retried.  Favicons are cosmetic, so paying 3s of radio time per
    /// cold launch on known-missing hosts is wasted energy — but a full
    /// lifetime skip would never recover if the host later publishes an
    /// icon.  One day strikes the balance.
    static let failedLookupTTL: TimeInterval = 24 * 60 * 60

    /// Persisted map of `cacheKey → failure date`.  Lives alongside the
    /// favicon PNGs so `clearCache()` removes it too.
    static let failedLookupsFileName = "failedLookups.json"

    var failedLookupsURL: URL {
        cacheDirectory.appendingPathComponent(Self.failedLookupsFileName)
    }

    /// Loads and prunes the on-disk failure map.  Entries older than the
    /// TTL are dropped; the caller is responsible for persisting the
    /// pruned state.  `nonisolated` so `init` can call it before the
    /// actor's properties are fully wired up.
    nonisolated static func loadFailedLookupsFromDisk(at url: URL) -> [String: Date] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        let now = Date().timeIntervalSince1970
        var pruned: [String: Date] = [:]
        for (key, timestamp) in stored where now - timestamp < failedLookupTTL {
            pruned[key] = Date(timeIntervalSince1970: timestamp)
        }
        return pruned
    }

    /// Returns true if `cacheKey` has failed within the TTL window.
    /// Stale entries are evicted on check so they don't linger in memory.
    func isWithinFailureTTL(_ cacheKey: String) -> Bool {
        guard let failedAt = failedLookups[cacheKey] else { return false }
        if Date().timeIntervalSince(failedAt) < Self.failedLookupTTL {
            return true
        }
        failedLookups.removeValue(forKey: cacheKey)
        persistFailedLookups()
        return false
    }

    func recordFailedLookup(_ cacheKey: String) {
        failedLookups[cacheKey] = Date()
        persistFailedLookups()
    }

    func forgetFailedLookup(_ cacheKey: String) {
        guard failedLookups.removeValue(forKey: cacheKey) != nil else { return }
        persistFailedLookups()
    }

    func forgetAllFailedLookups() {
        guard !failedLookups.isEmpty else { return }
        failedLookups.removeAll()
        persistFailedLookups()
    }

    private func persistFailedLookups() {
        let serialized = failedLookups.mapValues { $0.timeIntervalSince1970 }
        guard let data = try? JSONEncoder().encode(serialized) else { return }
        try? data.write(to: failedLookupsURL, options: .atomic)
    }
}
