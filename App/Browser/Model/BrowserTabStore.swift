import Observation
import SwiftUI

@MainActor
@Observable
final class BrowserTabStore {

    /// Tabs beyond this many are torn down and rebuilt from their stored path
    /// when revisited, so twenty open feeds do not mean twenty live article lists.
    static let liveTabLimit = 4

    private(set) var tabs: [BrowserTab]
    private(set) var selectedTabID: UUID
    private(set) var liveTabIDs: [UUID]
    var visitCounts: [String: Int]

    var isShowingTabSwitcher = false

    init(tabs: [BrowserTab] = [], selectedTabID: UUID? = nil) {
        let restored = tabs.isEmpty ? [BrowserTab()] : tabs
        self.tabs = restored
        let selected = selectedTabID.flatMap { candidate in
            restored.contains { $0.id == candidate } ? candidate : nil
        }
        let resolved = selected ?? restored[0].id
        self.selectedTabID = resolved
        self.liveTabIDs = [resolved]
        self.visitCounts = BrowserTabStore.loadVisitCounts()
    }

    var selectedTab: BrowserTab {
        tabs.first { $0.id == selectedTabID } ?? tabs[0]
    }

    private var selectedIndex: Int {
        tabs.firstIndex { $0.id == selectedTabID } ?? 0
    }

    func isLive(_ tabID: UUID) -> Bool {
        liveTabIDs.contains(tabID)
    }

    // MARK: - Tab lifecycle

    func select(_ tabID: UUID) {
        guard tabs.contains(where: { $0.id == tabID }) else { return }
        selectedTabID = tabID
        touch(tabID)
        markLive(tabID)
    }

    @discardableResult
    func openTab(at location: BrowserLocation = .startPage, inBackground: Bool = false) -> UUID {
        let tab = BrowserTab(location: location)
        tabs.append(tab)
        recordVisit(location)
        if !inBackground {
            selectedTabID = tab.id
            markLive(tab.id)
        }
        persistTabs()
        return tab.id
    }

    func close(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs.remove(at: index)
        liveTabIDs.removeAll { $0 == tabID }
        if tabs.isEmpty {
            let replacement = BrowserTab()
            tabs = [replacement]
            selectedTabID = replacement.id
            liveTabIDs = [replacement.id]
        } else if selectedTabID == tabID {
            let neighbour = tabs[min(index, tabs.count - 1)]
            selectedTabID = neighbour.id
            markLive(neighbour.id)
        }
        persistTabs()
    }

    func closeAll() {
        let replacement = BrowserTab()
        tabs = [replacement]
        selectedTabID = replacement.id
        liveTabIDs = [replacement.id]
        persistTabs()
    }

    // MARK: - Navigation

    /// Pushes a location onto the selected tab, so moving between pages gets
    /// the system's push animation and its interactive back gesture rather
    /// than swapping the stack's root out from under itself.
    func navigate(to location: BrowserLocation) {
        let index = selectedIndex
        tabs[index].path.append(location)
        tabs[index].lastVisited = .now
        recordVisit(location)
        markLive(tabs[index].id)
    }

    func push<Value: Hashable>(_ value: Value) {
        let index = selectedIndex
        tabs[index].path.append(value)
        tabs[index].lastVisited = .now
    }

    func goBack() {
        let index = selectedIndex
        guard !tabs[index].path.isEmpty else { return }
        tabs[index].path.removeLast()
        tabs[index].lastVisited = .now
    }

    func popToRoot() {
        tabs[selectedIndex].path = NavigationPath()
    }

    func pathBinding(for tabID: UUID) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                self?.tabs.first { $0.id == tabID }?.path ?? NavigationPath()
            },
            set: { [weak self] newPath in
                guard let self, let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
                tabs[index].path = newPath
                tabs[index].lastVisited = .now
            }
        )
    }

    func setPageIdentity(_ identity: BrowserPageIdentity?, for tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].pageIdentity != identity else { return }
        tabs[index].pageIdentity = identity
    }

    // MARK: - Liveness

    private func markLive(_ tabID: UUID) {
        liveTabIDs.removeAll { $0 == tabID }
        liveTabIDs.append(tabID)
        while liveTabIDs.count > BrowserTabStore.liveTabLimit {
            liveTabIDs.removeFirst()
        }
    }

    private func touch(_ tabID: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].lastVisited = .now
    }
}
