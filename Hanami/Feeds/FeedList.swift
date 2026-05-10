import Foundation

public nonisolated struct FeedList: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var icon: String
    public var displayStyle: String?
    public var sortOrder: Int
}
