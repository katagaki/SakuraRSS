import Foundation

public extension TabNavigationStore {

    /// Each tab is restored down to the page it was left on: the root from its
    /// token, and the stack above it from the path tokens recorded in its page
    /// history, which `restorePathIfNeeded` turns back into values.
    static func restored(configuration: TabStoreConfiguration) -> TabNavigationStore {
        let keys = PersistenceKeys(prefix: configuration.persistenceKeyPrefix)
        let defaults = UserDefaults.standard
        let tokens = defaults.stringArray(forKey: keys.tabTokens) ?? []
        // Identities are restored too: snapshots are filed under the tab's id,
        // so a fresh one would orphan them.
        let identifiers = defaults.stringArray(forKey: keys.tabIDs) ?? []
        let restoredTabs = tokens.enumerated().compactMap { index, token -> Tab? in
            guard let root = Root(persistenceToken: token) else { return nil }
            let identifier = identifiers.indices.contains(index)
                ? UUID(uuidString: identifiers[index])
                : nil
            return Tab(id: identifier ?? UUID(), root: root)
        }
        let index = defaults.integer(forKey: keys.selectedTabIndex)
        let selected = restoredTabs.indices.contains(index) ? restoredTabs[index].id : nil
        return TabNavigationStore(
            configuration: configuration,
            tabs: restoredTabs,
            selectedTabID: selected,
            pageHistories: loadPageHistories(for: restoredTabs.map(\.id), key: keys.pageHistories)
        )
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

    /// Roots ordered by how often they have been opened.
    var frequentlyVisitedRoots: [Root] {
        visitCounts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .compactMap { Root(persistenceToken: $0.key) }
            .prefix(configuration.frequentlyVisitedLimit)
            .map { $0 }
    }
}

extension TabNavigationStore {

    struct PersistenceKeys {
        let tabTokens: String
        let tabIDs: String
        let selectedTabIndex: String
        let visitCounts: String
        let pageHistories: String

        init(prefix: String) {
            tabTokens = "\(prefix).TabTokens"
            tabIDs = "\(prefix).TabIDs"
            selectedTabIndex = "\(prefix).SelectedTabIndex"
            visitCounts = "\(prefix).VisitCounts"
            pageHistories = "\(prefix).PageHistories"
        }
    }

    var persistenceKeys: PersistenceKeys {
        PersistenceKeys(prefix: configuration.persistenceKeyPrefix)
    }

    static func loadVisitCounts(configuration: TabStoreConfiguration) -> [String: Int] {
        let key = PersistenceKeys(prefix: configuration.persistenceKeyPrefix).visitCounts
        return UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    func recordVisit(_ root: Root) {
        guard root.isRecordedAsVisit else { return }
        visitCounts[root.persistenceToken, default: 0] += 1
        UserDefaults.standard.set(visitCounts, forKey: persistenceKeys.visitCounts)
    }

    private static func loadPageHistories(for tabIDs: [UUID], key: String) -> [UUID: [Identity]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stored = try? JSONDecoder().decode([String: [Identity]].self, from: data)
        else { return [:] }
        let kept = Set(tabIDs.map(\.uuidString))
        return stored.reduce(into: [:]) { histories, entry in
            guard kept.contains(entry.key), let tabID = UUID(uuidString: entry.key) else { return }
            histories[tabID] = entry.value
        }
    }

    private func writeTabs() {
        let keys = persistenceKeys
        let defaults = UserDefaults.standard
        defaults.set(tabs.map(\.root.persistenceToken), forKey: keys.tabTokens)
        defaults.set(tabs.map(\.id.uuidString), forKey: keys.tabIDs)
        let index = tabs.firstIndex { $0.id == selectedTabID } ?? 0
        defaults.set(index, forKey: keys.selectedTabIndex)
        persistPageHistories(key: keys.pageHistories)
    }

    /// The history is trimmed to the page each tab is actually on: anything
    /// deeper was popped away, and restoring it would push pages the user has
    /// already left. A tab still waiting to be rebuilt is written back as it
    /// was read, since its own path is empty until then.
    private func persistPageHistories(key: String) {
        let stored = tabs.reduce(into: [String: [Identity]]()) { histories, tab in
            guard let history = pageHistories[tab.id] else { return }
            let depth = restorableDepth(for: tab)
            histories[tab.id.uuidString] = Array(history.prefix(depth + 1))
        }
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
