import SwiftUI
import Hanami

struct BookmarkSortMenu: View {

    @Binding var sortOrder: BookmarkSortOrder

    var body: some View {
        Picker(String(localized: "Bookmarks.Sort", table: "Articles"), selection: $sortOrder) {
            ForEach(BookmarkSortOrder.allCases) { order in
                Label(label(for: order), systemImage: order.symbol)
                    .tag(order)
            }
        }
    }

    private func label(for order: BookmarkSortOrder) -> String {
        switch order {
        case .newest: String(localized: "Bookmarks.Sort.Newest", table: "Articles")
        case .oldest: String(localized: "Bookmarks.Sort.Oldest", table: "Articles")
        case .title: String(localized: "Bookmarks.Sort.Title", table: "Articles")
        case .site: String(localized: "Bookmarks.Sort.Site", table: "Articles")
        }
    }
}
