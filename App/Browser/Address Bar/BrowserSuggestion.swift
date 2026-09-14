import Foundation
import Hanami

struct BrowserSuggestion: Identifiable {

    enum Kind {
        case place(BrowserLocation)
        case feed(Feed)
        case list(FeedList)
        case article(Article)
        case searchContent(String)
        case discoverFeeds(String)
    }

    enum Section: Int, CaseIterable {
        case actions
        case feeds
        case lists
        case content
        case places

        var title: String {
            switch self {
            case .actions: String(localized: "Suggestions.Actions", table: "Browser")
            case .feeds: String(localized: "Suggestions.Feeds", table: "Browser")
            case .lists: String(localized: "Suggestions.Lists", table: "Browser")
            case .content: String(localized: "Suggestions.Content", table: "Browser")
            case .places: String(localized: "Suggestions.Places", table: "Browser")
            }
        }
    }

    let id: String
    let kind: Kind
    let section: Section
}
