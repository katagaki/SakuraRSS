import SwiftUI
import Hanami

/// Makes article rows in the Bookmarks tab draggable into folders and adds
/// a trailing swipe action that picks a destination folder. Inert elsewhere.
struct MoveBookmarkToFolderRowModifier: ViewModifier {

    @Environment(\.allowsMovingBookmarksToFolders) private var allowsMoving
    @Environment(FeedManager.self) private var feedManager
    let article: Article

    @State private var isShowingFolderPicker = false

    func body(content: Content) -> some View {
        if allowsMoving && !feedManager.bookmarkFolders.isEmpty {
            content
                .draggable(BookmarkDragPayload.encode(articleID: article.id))
                .swipeActions(edge: .trailing) {
                    Button {
                        isShowingFolderPicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                    .tint(.indigo)
                }
                .sheet(isPresented: $isShowingFolderPicker) {
                    MoveToFolderSheet(article: article)
                        .environment(feedManager)
                        .presentationDetents([.medium, .large])
                }
        } else {
            content
        }
    }
}
