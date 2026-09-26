import SwiftUI
import Hanami

extension BookmarksContentView {

    /// Export, sort and display style only apply once something is saved, so
    /// they drop out of the menu while the collection is empty.
    var browserBookmarksActions: BrowserBookmarksActions {
        let hasBookmarks = !bookmarkedArticles.isEmpty
        return BrowserBookmarksActions(
            createFolder: { isCreatingFolder = true },
            export: hasBookmarks ? { isExporting = true } : nil,
            removeReadBookmarks: hasBookmarks ? { showingDeleteReadAlert = true } : nil,
            scope: $scope,
            sortOrder: $sortOrder,
            displayStyle: $displayStyle,
            hasImages: hasImages
        )
    }
}
