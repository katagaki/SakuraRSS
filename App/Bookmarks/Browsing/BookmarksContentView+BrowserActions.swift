import SwiftUI
import Hanami

extension BookmarksContentView {

    /// Re-sent whenever the state behind these actions changes, since the bar
    /// holds them rather than re-reading the page.
    func reportBrowserBookmarksActions() {
        guard isBrowserChromeActive else {
            browserBookmarksActionsReporter?(nil)
            return
        }
        browserBookmarksActionsReporter?(browserBookmarksActions)
    }

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
