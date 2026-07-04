import SwiftUI
import Hanami

/// Confirmation toast shown after bookmarking. Tapping it opens a menu that
/// files the new bookmark into a folder.
struct BookmarkToastView: View {

    @Environment(FeedManager.self) private var feedManager
    let article: Article

    var body: some View {
        if feedManager.bookmarkFolders.isEmpty {
            BookmarkToastLabel(showsFolderHint: false)
        } else {
            Menu {
                Section(String(localized: "BookmarkToast.AddToFolder", table: "Articles")) {
                    ForEach(feedManager.bookmarkFolders) { folder in
                        Button {
                            addToFolder(folder)
                        } label: {
                            Label(folder.name, systemImage: folder.icon)
                        }
                    }
                }
            } label: {
                BookmarkToastLabel(showsFolderHint: true)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                BookmarkToastManager.shared.delayDismissal()
            })
        }
    }

    private func addToFolder(_ folder: BookmarkFolder) {
        feedManager.moveBookmark(articleID: article.id, to: folder)
        Haptics.notify(.success)
        BookmarkToastManager.shared.dismiss()
    }
}
