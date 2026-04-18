import Foundation

nonisolated struct FeedList: Identifiable, Hashable, Sendable {
    let id: Int64
    var name: String
    var icon: String
    var displayStyle: String?
    var sortOrder: Int
}
