import SwiftUI
import Hanami

/// Folders and tags stacked above the bookmark list: the organization the
/// user built, before the content itself.
struct BookmarksHeaderSections: View {

    @Environment(FeedManager.self) private var feedManager

    /// Non-nil only where the host has no navigation bar to put search in.
    var inlineSearchText: Binding<String>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let inlineSearchText {
                BookmarkInlineSearchField(searchText: inlineSearchText)
            }
            BookmarkSmartGroupsRow()
            if !feedManager.bookmarkFolders.isEmpty {
                BookmarkFoldersGridSection()
            }
            BookmarkTagsSection()
        }
    }
}
