import Foundation

extension FeedManager {

    static let searchHistoryDefaultsKey = "FeedManager.SearchHistory"
    static let searchHistoryLimit = 5

    static func loadSearchHistory() -> [String] {
        let stored = UserDefaults.standard.stringArray(forKey: FeedManager.searchHistoryDefaultsKey) ?? []
        return Array(stored.prefix(FeedManager.searchHistoryLimit))
    }

    func recordSearchTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = searchHistory.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > FeedManager.searchHistoryLimit {
            updated = Array(updated.prefix(FeedManager.searchHistoryLimit))
        }
        searchHistory = updated
    }

    func clearSearchHistory() {
        searchHistory = []
    }
}
