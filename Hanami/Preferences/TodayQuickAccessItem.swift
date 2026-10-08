import Foundation

public nonisolated enum TodayQuickAccessItem: Hashable, Sendable, Identifiable {
    case following
    case allContent
    case bookmarks
    case topics
    case feedSection(FeedSection)
    case list(Int64)

    public var id: String {
        switch self {
        case .following: "following"
        case .allContent: "allContent"
        case .bookmarks: "bookmarks"
        case .topics: "topics"
        case .feedSection(let section): "section.\(section.rawValue)"
        case .list(let listID): "list.\(listID)"
        }
    }
}
