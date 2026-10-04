import Foundation
import Hanami

struct AddressSuggestion {

    enum Kind {
        case location(BrowserLocation)
        case searchContent(String)
        case discoverFeeds(String)
    }

    enum Section: Int, CaseIterable {
        case actions
        case places
        case feeds
        case lists
        case content

        var title: String {
            switch self {
            case .actions: String(localized: "Suggestions.Actions", table: "Browser")
            case .places: String(localized: "Suggestions.Places", table: "Browser")
            case .feeds: String(localized: "Suggestions.Feeds", table: "Browser")
            case .lists: String(localized: "Suggestions.Lists", table: "Browser")
            case .content: String(localized: "Suggestions.Content", table: "Browser")
            }
        }
    }

    let kind: Kind
    let section: Section
    let title: String
    let subtitle: String?
    let symbolName: String
}
