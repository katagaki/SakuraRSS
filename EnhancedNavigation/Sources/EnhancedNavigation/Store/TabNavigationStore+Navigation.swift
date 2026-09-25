import SwiftUI

public extension TabNavigationStore {

    /// Pushes a root onto the selected tab, so moving between pages gets the
    /// system's push animation and its interactive back gesture rather than
    /// swapping the stack's root out from under itself.
    func navigate(to root: Root) {
        updateSelectedTab { $0.path.append(root) }
        recordVisit(root)
        markLive(selectedTabID)
        persistTabs()
    }

    func push<Value: Hashable>(_ value: Value) {
        updateSelectedTab { $0.path.append(value) }
        persistTabs()
    }

    func goBack() {
        if let overlay = displayedOverlayPage {
            setOverlayPage(nil, id: overlay.id, for: selectedTabID)
            overlay.dismiss()
            return
        }
        guard selectedTab.canGoBack else { return }
        updateSelectedTab { $0.path.removeLast() }
        restoreIdentity(atDepth: selectedTab.path.count, for: selectedTabID)
        persistTabs()
    }

    func popTo(depth: Int) {
        let current = selectedTab.path.count
        guard depth < current else { return }
        updateSelectedTab { $0.path.removeLast(current - depth) }
        restoreIdentity(atDepth: depth, for: selectedTabID)
        persistTabs()
    }

    func pathBinding(for tabID: UUID) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in
                self?.tab(tabID)?.path ?? NavigationPath()
            },
            set: { [weak self] newPath in
                guard let self else { return }
                let previousDepth = tab(tabID)?.path.count ?? 0
                updateTab(tabID) { $0.path = newPath }
                clearOverlayPages(for: tabID)
                if newPath.count < previousDepth {
                    restoreIdentity(atDepth: newPath.count, for: tabID)
                }
                persistTabs()
            }
        )
    }

    func beginInteractivePop() {
        guard !isInteractivelyPopping else { return }
        frozenCanGoBack = selectedTab.canGoBack
        frozenPageIdentity = selectedTab.pageIdentity
        isInteractivelyPopping = true
    }

    /// A cancelled swipe leaves the revealed page's identity reported as the
    /// tab's own: it appeared, and nothing re-reports the page that never
    /// actually left. Put the frozen one back before unfreezing, or the chrome
    /// flips to the previous page the moment the gesture is let go.
    func endInteractivePop(cancelled: Bool) {
        guard isInteractivelyPopping else { return }
        if cancelled, let index = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            tabs[index].pageIdentity = frozenPageIdentity
        }
        isInteractivelyPopping = false
        frozenCanGoBack = nil
        frozenPageIdentity = nil
        stopMediaLeftBehind(in: selectedTabID)
    }
}
