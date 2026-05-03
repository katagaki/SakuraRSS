import Foundation
import Observation

/// Persistent store of recent search terms used by the Discover tab.
@Observable
final class RecentSearchStore {

    static let shared = RecentSearchStore()

    static let defaultsKey = "Search.RecentSearches"
    static let maximumCount = 10

    private(set) var searches: [String]

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        searches = stored
    }

    func add(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = searches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > Self.maximumCount {
            updated = Array(updated.prefix(Self.maximumCount))
        }
        searches = updated
        persist()
    }

    func remove(_ term: String) {
        let updated = searches.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        guard updated.count != searches.count else { return }
        searches = updated
        persist()
    }

    func clear() {
        searches = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(searches, forKey: Self.defaultsKey)
    }
}
