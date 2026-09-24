import SwiftUI
import Hanami

extension FollowingPage {

    /// Everything the bottom bar's copy of these controls is drawn from,
    /// collapsed into one value so the page watches it with a single
    /// `onChange` rather than one per piece of state.
    var browserActionsSignal: [Int] {
        [
            isEditingFeeds ? 1 : 0,
            isSelectingFeeds ? 1 : 0,
            selectedFeedIDs.count,
            feedManager.feeds.count
        ]
    }

    /// Re-sent whenever the state behind these controls changes, since the bar
    /// holds them rather than re-reading the page.
    func reportBrowserFollowingActions() {
        guard isBrowserChromeActive else {
            browserFollowingActionsReporter?(nil)
            return
        }
        browserFollowingActionsReporter?(browserFollowingActions)
    }

    var browserFollowingActions: BrowserFollowingActions {
        let hasSomethingToEdit = !feedManager.feeds.isEmpty
        return BrowserFollowingActions(
            addFeed: { isPresentingAddFeedSheet = true },
            newList: { isPresentingNewListSheet = true },
            beginEditing: hasSomethingToEdit ? { isEditingFeeds = true } : nil,
            isEditing: isEditingFeeds,
            isSelecting: isSelectingFeeds,
            toggleSelectMode: { toggleSelectMode() },
            endEditing: { exitEditMode() },
            selectedCount: selectedFeedIDs.count,
            editSelected: { isPresentingBulkEditSheet = true },
            deleteSelected: { isPresentingBulkDeleteAlert = true }
        )
    }
}
