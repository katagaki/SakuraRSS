import Foundation
import Hanami

enum BookmarkSorting {

    static func sorted(_ articles: [Article], by order: BookmarkSortOrder,
                       siteName: (Article) -> String) -> [Article] {
        switch order {
        case .newest:
            articles
        case .oldest:
            articles.reversed()
        case .title:
            articles.sorted {
                $0.displayTitle.localizedStandardCompare($1.displayTitle) == .orderedAscending
            }
        case .site:
            articles.sorted { first, second in
                let firstSite = siteName(first)
                let secondSite = siteName(second)
                guard firstSite != secondSite else { return false }
                return firstSite.localizedStandardCompare(secondSite) == .orderedAscending
            }
        }
    }

    static func matches(_ article: Article, query: String, tagNames: [String]) -> Bool {
        if article.displayTitle.localizedCaseInsensitiveContains(query) { return true }
        if article.title.localizedCaseInsensitiveContains(query) { return true }
        if article.url.localizedCaseInsensitiveContains(query) { return true }
        if let summary = article.summary, summary.localizedCaseInsensitiveContains(query) {
            return true
        }
        return tagNames.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}
