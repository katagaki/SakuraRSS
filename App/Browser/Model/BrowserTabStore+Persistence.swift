import Foundation

extension BrowserTabStore {

    private static let tabTokensKey = "Browser.TabTokens"
    private static let tabIDsKey = "Browser.TabIDs"
    private static let selectedTokenIndexKey = "Browser.SelectedTabIndex"
    private static let visitCountsKey = "Browser.VisitCounts"
    private static let pageHistoriesKey = "Browser.PageHistories"
    private static let frequentlyVisitedLimit = 8

    /// Each tab is restored down to the page it was left on: the root from its
    /// location, and the stack above it from the identifiers recorded in its
    /// page history. The rows themselves are looked up again on first use.
    static func restored() -> BrowserTabStore {
        let tokens = UserDefaults.standard.stringArray(forKey: tabTokensKey) ?? []
        // Identities are restored too: snapshots are filed under the tab's id,
        // so a fresh one would orphan them.
        let identifiers = UserDefaults.standard.stringArray(forKey: tabIDsKey) ?? []
        let restoredTabs = tokens.enumerated().compactMap { index, token -> BrowserTab? in
            guard let location = BrowserLocation.resolve(token: token) else { return nil }
            let identifier = identifiers.indices.contains(index)
                ? UUID(uuidString: identifiers[index])
                : nil
            return BrowserTab(id: identifier ?? UUID(), location: location)
        }
        let index = UserDefaults.standard.integer(forKey: selectedTokenIndexKey)
        let selected = restoredTabs.indices.contains(index) ? restoredTabs[index].id : nil
        return BrowserTabStore(
            tabs: restoredTabs,
            selectedTabID: selected,
            pageHistories: loadPageHistories(for: restoredTabs.map(\.id))
        )
    }

    private static func loadPageHistories(for tabIDs: [UUID]) -> [UUID: [BrowserPageIdentity]] {
        guard let data = UserDefaults.standard.data(forKey: pageHistoriesKey),
              let stored = try? JSONDecoder().decode([String: [BrowserPageIdentity]].self, from: data)
        else { return [:] }
        let kept = Set(tabIDs.map(\.uuidString))
        return stored.reduce(into: [:]) { histories, entry in
            guard kept.contains(entry.key), let tabID = UUID(uuidString: entry.key) else { return }
            histories[tabID] = entry.value
        }
    }

    /// Coalesced to one write per run loop pass: a restored stack reports
    /// every page in it, and each report would otherwise encode every tab's
    /// history and write it all out again.
    func persistTabs() {
        guard !isPersistenceScheduled else { return }
        isPersistenceScheduled = true
        Task { @MainActor in
            self.isPersistenceScheduled = false
            self.writeTabs()
        }
    }

    private func writeTabs() {
        let tokens = tabs.map(\.location.persistenceToken)
        UserDefaults.standard.set(tokens, forKey: BrowserTabStore.tabTokensKey)
        UserDefaults.standard.set(
            tabs.map(\.id.uuidString),
            forKey: BrowserTabStore.tabIDsKey
        )
        let index = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        UserDefaults.standard.set(index, forKey: BrowserTabStore.selectedTokenIndexKey)
        persistPageHistories()
    }

    /// The history is trimmed to the page each tab is actually on: anything
    /// deeper was popped away, and restoring it would push pages the user has
    /// already left. A tab still waiting to be rebuilt is written back as it
    /// was read, since its own path is empty until then.
    private func persistPageHistories() {
        let stored = tabs.reduce(into: [String: [BrowserPageIdentity]]()) { histories, tab in
            guard let history = pageHistories[tab.id] else { return }
            let depth = restorableDepth(for: tab)
            histories[tab.id.uuidString] = Array(history.prefix(depth + 1))
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: BrowserTabStore.pageHistoriesKey)
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
