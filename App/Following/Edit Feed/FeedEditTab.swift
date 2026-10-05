import Foundation
import Hanami

enum FeedEditTab: Hashable, CaseIterable {
    case about
    case content
    case display
    case rules
    case lists

    var localizedTitle: String {
        switch self {
        case .about: String(localized: "FeedEditSheet.Tab.About", table: "Feeds")
        case .content: String(localized: "FeedEditSheet.Tab.Content", table: "Feeds")
        case .display: String(localized: "FeedEditSheet.Tab.Display", table: "Feeds")
        case .rules: String(localized: "FeedEditSheet.Tab.Rules", table: "Feeds")
        case .lists: String(localized: "FeedEditSheet.Tab.Lists", table: "Feeds")
        }
    }
}
