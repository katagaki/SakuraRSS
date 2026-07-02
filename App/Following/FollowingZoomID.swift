import Hanami

enum FollowingZoomID {
    static func feed(_ id: Int64) -> String { "feed-\(id)" }
    static func list(_ id: Int64) -> String { "list-\(id)" }
    static func section(_ section: FeedSection) -> String { "section-\(section.rawValue)" }
}
