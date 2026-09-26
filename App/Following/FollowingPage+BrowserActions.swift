import SwiftUI
import Hanami

extension FollowingPage {

    var browserFollowingActions: BrowserFollowingActions {
        let hasSomethingToEdit = !feedManager.feeds.isEmpty
        return BrowserFollowingActions(
            addFeed: { isPresentingAddFeedSheet = true },
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
