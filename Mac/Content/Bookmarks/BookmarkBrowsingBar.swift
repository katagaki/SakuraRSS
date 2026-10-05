import Hanami
import SwiftUI

/// Search, scope, sort and the collection's actions above a Bookmarks page's list.
struct BookmarkBrowsingBar: View {

    @Bindable var browsing: BookmarkBrowsing
    let showsScope: Bool
    let onExport: () -> Void
    let onRemoveReadBookmarks: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(String(localized: "Bookmarks.Search.Prompt", table: "Articles"), text: $browsing.searchText)
                .textFieldStyle(.roundedBorder)
            Menu {
                if showsScope {
                    BookmarkScopeMenu(scope: $browsing.scope)
                    Divider()
                }
                BookmarkSortMenu(sortOrder: $browsing.sortOrder)
                Divider()
                Button(String(localized: "BookmarksExport.Title", table: "Articles"),
                       systemImage: "square.and.arrow.up", action: onExport)
                if showsScope {
                    Button(String(localized: "Bookmarks.DeleteAllRead", table: "Articles"),
                           systemImage: "trash", role: .destructive, action: onRemoveReadBookmarks)
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(String(localized: "Bookmarks.Sort", table: "Articles"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
