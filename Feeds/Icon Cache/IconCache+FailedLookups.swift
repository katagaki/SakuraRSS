import Foundation

extension IconCache {

    static let failedLookupTTL: TimeInterval = 24 * 60 * 60
    static let failedLookupsFileName = "failedLookups.json"

    var failedLookupsURL: URL {
        cacheDirectory.appendingPathComponent(Self.failedLookupsFileName)
    }

    /// Loads and prunes the on-disk failure map, dropping entries past the TTL.
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
