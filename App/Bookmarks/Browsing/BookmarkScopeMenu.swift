import SwiftUI
import Hanami

/// Which bookmarks the page lists. A filter rather than a place, so it changes
/// the list in front of the reader instead of pushing a second screen.
struct BookmarkScopeMenu: View {

    @Binding var scope: BookmarkSmartGroup

    var body: some View {
        Picker(String(localized: "Bookmarks.Scope", table: "Articles"), selection: $scope) {
            ForEach(BookmarkSmartGroup.allCases) { group in
                Label(BookmarkSmartGroupLabel.title(for: group), systemImage: group.symbol)
                    .tag(group)
            }
        }
    }
}

enum BookmarkSmartGroupLabel {
    static func title(for group: BookmarkSmartGroup) -> String {
        switch group {
        case .all: String(localized: "Bookmarks.Group.All", table: "Articles")
        case .unread: String(localized: "Bookmarks.Group.Unread", table: "Articles")
        case .unsorted: String(localized: "Bookmarks.Group.Unsorted", table: "Articles")
        }
    }
}
