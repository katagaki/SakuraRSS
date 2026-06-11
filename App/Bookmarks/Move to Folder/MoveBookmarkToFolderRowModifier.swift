import SwiftUI
import Hanami

/// Makes article rows in the Bookmarks tab draggable into folder
/// grid cells. Inert elsewhere.
struct MoveBookmarkToFolderRowModifier: ViewModifier {

    @Environment(\.allowsMovingBookmarksToFolders) private var allowsMoving
    @Environment(FeedManager.self) private var feedManager
    let article: Article

    func body(content: Content) -> some View {
        if allowsMoving && !feedManager.bookmarkFolders.isEmpty {
            content
                .draggable(BookmarkDragPayload.encode(articleID: article.id))
        } else {
            content
        }
    }
}
