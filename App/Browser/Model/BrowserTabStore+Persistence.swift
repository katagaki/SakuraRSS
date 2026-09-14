import Foundation

extension BrowserTabStore {

    private static let tabTokensKey = "Browser.TabTokens"
    private static let selectedTokenIndexKey = "Browser.SelectedTabIndex"
    private static let visitCountsKey = "Browser.VisitCounts"
    private static let frequentlyVisitedLimit = 8

    /// Only the root of each tab is persisted. Pushed destinations hold live
    /// database rows, so they are rebuilt by revisiting rather than restored.
    static func restored() -> BrowserTabStore {
        let tokens = UserDefaults.standard.stringArray(forKey: tabTokensKey) ?? []
        let restoredTabs = tokens
            .compactMap(BrowserLocation.resolve(token:))
            .map { BrowserTab(location: $0) }
        let index = UserDefaults.standard.integer(forKey: selectedTokenIndexKey)
        let selected = restoredTabs.indices.contains(index) ? restoredTabs[index].id : nil
        return BrowserTabStore(tabs: restoredTabs, selectedTabID: selected)
    }

    func persistTabs() {
        let tokens = tabs.map(\.location.persistenceToken)
        UserDefaults.standard.set(tokens, forKey: BrowserTabStore.tabTokensKey)
        let index = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        UserDefaults.standard.set(index, forKey: BrowserTabStore.selectedTokenIndexKey)
    }

    static func loadVisitCounts() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: visitCountsKey) as? [String: Int] ?? [:]
    }

    func recordVisit(_ location: BrowserLocation) {
        guard case .feed = location else { return }
        let token = location.persistenceToken
        visitCounts[token, default: 0] += 1
        UserDefaults.standard.set(visitCounts, forKey: BrowserTabStore.visitCountsKey)
    }

    func clearVisitCounts() {
        visitCounts = [:]
        UserDefaults.standard.removeObject(forKey: BrowserTabStore.visitCountsKey)
    }

    /// Feed identifiers ordered by how often this browser has opened them.
    var frequentlyVisitedFeedIDs: [Int64] {
        visitCounts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .compactMap { entry in
                guard case .feed(let feedID)? = BrowserLocation.resolve(token: entry.key) else { return nil }
                return feedID
            }
            .prefix(BrowserTabStore.frequentlyVisitedLimit)
            .map { $0 }
    }
}
