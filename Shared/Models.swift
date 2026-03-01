import Foundation

nonisolated struct Feed: Identifiable, Hashable, Sendable {
    let id: Int64
    var title: String
    var url: String
    var siteURL: String
    var feedDescription: String
    var faviconURL: String?
    var lastFetched: Date?
    var category: String?

    var domain: String {
        URL(string: siteURL)?.host ?? URL(string: url)?.host ?? ""
    }
}

nonisolated struct Article: Identifiable, Hashable, Sendable {
    let id: Int64
    let feedID: Int64
    var title: String
    var url: String
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedDate: Date?
    var isRead: Bool
    var isBookmarked: Bool
}

nonisolated enum FeedDisplayStyle: String, CaseIterable, Sendable {
    case inbox
    case magazine
    case compact
}
