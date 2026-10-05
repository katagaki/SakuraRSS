import Foundation
import Hanami
import Observation

/// What the Bookmarks pages are filtered and sorted by, as iOS's Bookmarks
/// offers: a scope on the Bookmarks page itself, and a search and sort order
/// on every Bookmarks page.
@Observable
final class BookmarkBrowsing {

    var scope: BookmarkSmartGroup = .all
    var searchText = ""
    var sortOrder: BookmarkSortOrder = UserDefaults.standard.string(forKey: BookmarkSortOrder.storageKey)
        .flatMap(BookmarkSortOrder.init(rawValue:)) ?? .newest {
        didSet { UserDefaults.standard.set(sortOrder.rawValue, forKey: BookmarkSortOrder.storageKey) }
    }
    /// Tag names for each bookmark, so search finds bookmarks by their tags.
    @ObservationIgnored var tagNamesByArticleID: [Int64: [String]] = [:]

    var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    func apply(to articles: [Article], feedManager: FeedManager) -> [Article] {
        let query = query
        let matching = query.isEmpty ? articles : articles.filter { article in
            BookmarkSorting.matches(article, query: query, tagNames: tagNamesByArticleID[article.id] ?? [])
        }
        return BookmarkSorting.sorted(matching, by: sortOrder) { article in
            feedManager.feedsByID[article.feedID]?.title ?? URL(string: article.url)?.host() ?? article.url
        }
    }
}

extension BrowserLocation {

    var isBookmarksPage: Bool {
        switch self {
        case .bookmarks, .bookmarkFolder, .bookmarkTag: true
        default: false
        }
    }
}
