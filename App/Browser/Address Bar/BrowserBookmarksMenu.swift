import SwiftUI
import Hanami

/// The Bookmarks page's actions, in the bottom bar slot the article viewer
/// uses for its own ellipsis menu.
struct BrowserBookmarksMenu: View {

    let actions: BrowserBookmarksActions

    var body: some View {
        Menu {
            Button(action: actions.createFolder) {
                Label(String(localized: "Folders.New", table: "Articles"),
                      systemImage: "folder.badge.plus")
            }

            if let export = actions.export {
                Button(action: export) {
                    Label(String(localized: "BookmarksExport.Title", table: "Articles"),
                          systemImage: "square.and.arrow.up")
                }
            }

            Section {
                BookmarkScopeMenu(scope: actions.scope)
            }

            if actions.export != nil {
                Section {
                    BookmarkSortMenu(sortOrder: actions.sortOrder)
                }
                Section {
                    DisplayStylePicker(
                        displayStyle: actions.displayStyle,
                        hasImages: actions.hasImages,
                        showCards: false,
                        showScroll: false
                    )
                }
            }

            if let removeReadBookmarks = actions.removeReadBookmarks {
                Section {
                    Button(role: .destructive, action: removeReadBookmarks) {
                        Label(String(localized: "Bookmarks.DeleteAllRead", table: "Articles"),
                              systemImage: "bookmark.slash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
        .menuActionDismissBehavior(.disabled)
    }
}
