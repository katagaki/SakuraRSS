import SwiftUI
import Hanami

/// Trailing swipe action that presents the folder picker sheet. Applied only
/// to list rows of styles where swipe gestures fit (Inbox); other styles
/// surface the move action through their context or ellipsis menus instead.
struct MoveToFolderSwipeActionModifier: ViewModifier {

    @Environment(\.allowsMovingBookmarksToFolders) private var allowsMoving
    @Environment(FeedManager.self) private var feedManager
    let article: Article

    @State private var isShowingFolderPicker = false

    func body(content: Content) -> some View {
        if allowsMoving && !feedManager.bookmarkFolders.isEmpty {
            content
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
