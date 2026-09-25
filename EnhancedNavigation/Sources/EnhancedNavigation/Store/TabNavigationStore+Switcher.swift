import SwiftUI

public extension TabNavigationStore {

    func showTabSwitcher() {
        captureSelectedTabSnapshot()
        freezeCollapseTarget()
        setWithoutAnimation { isShowingTabSwitcher = true }
        withAnimation(configuration.switcherAnimation, completionCriteria: .removed) {
            isPageCollapsed = true
        } completion: {
            // Not if the collapse was reversed while it ran: the completion
            // still fires, and the page is back at full screen by then.
            guard self.isPageCollapsed else { return }
            self.setWithoutAnimation { self.isPageSwappedForSnapshot = true }
        }
    }

    /// The chrome is handed back up front, mirroring the collapse. Waiting for
    /// the page to land leaves the switcher's own navigation bar blurring over
    /// the growing page, and swaps the bars under it at the very end, which
    /// nudges the page's content as it settles.
    func hideTabSwitcher() {
        freezeCollapseTarget()
        setWithoutAnimation { isShowingTabSwitcher = false }
        // A tick later: the page re-lays itself out around its own bars the
        // moment the chrome comes back, and doing that in the same pass as
        // the swap drops its content by a bar's height in the first frame of
        // the growth. Behind the snapshot it costs nothing.
        Task { @MainActor in
            self.setWithoutAnimation { self.isPageSwappedForSnapshot = false }
            withAnimation(self.configuration.switcherAnimation) {
                self.isPageCollapsed = false
            }
        }
    }

    func setCardFrame(_ frame: CGRect, for tabID: UUID) {
        guard cardFrames[tabID] != frame else { return }
        cardFrames[tabID] = frame
    }
}

extension TabNavigationStore {

    /// Outside the transition: changes flushed in the same cycle are otherwise
    /// swept into it.
    private func setWithoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    private func freezeCollapseTarget() {
        // Cleared, not left alone: a tab opened from the switcher has no frame
        // yet, and a stale one zooms out of the previously selected tab.
        collapseTarget = cardFrames[selectedTabID]
    }
}
