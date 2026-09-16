import SwiftUI
import Hanami

struct BookmarkSmartGroupsRow: View {

    @Environment(FeedManager.self) private var feedManager

    @State private var counts: [BookmarkSmartGroup: Int] = [:]

    private var populatedGroups: [BookmarkSmartGroup] {
        BookmarkSmartGroup.allCases.filter { (counts[$0] ?? 0) > 0 }
    }

    var body: some View {
        Group {
            if !populatedGroups.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(populatedGroups) { group in
                            NavigationLink(value: group) {
                                BookmarkSmartGroupChip(group: group, count: counts[group] ?? 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        .task(id: feedManager.dataRevision) {
            counts = await Task.detached {
                let database = DatabaseManager.shared
                return [
                    BookmarkSmartGroup.all: (try? database.bookmarkedCount()) ?? 0,
                    BookmarkSmartGroup.unread: (try? database.unreadBookmarkedCount()) ?? 0,
                    BookmarkSmartGroup.unsorted: (try? database.unorganizedBookmarkedCount()) ?? 0
                ]
            }.value
        }
    }
}

struct BookmarkSmartGroupChip: View {

    let group: BookmarkSmartGroup
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: group.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(BookmarkSmartGroupLabel.title(for: group))
                    .font(.subheadline.weight(.medium))
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quinary, in: .rect(cornerRadius: 14))
        .foregroundStyle(.primary)
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
