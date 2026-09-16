import SwiftUI
import Hanami

/// Folders and tags stacked above the bookmark list: the organization the
/// user built, before the content itself.
struct BookmarksHeaderSections: View {

    @Environment(FeedManager.self) private var feedManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BookmarkSmartGroupsRow()
            if !feedManager.bookmarkFolders.isEmpty {
                BookmarkFoldersGridSection()
            }
            BookmarkTagsSection()
        }
    }
}
