import Foundation

public nonisolated struct BookmarkFolder: Identifiable, Hashable, Sendable {
    public let id: Int64
    public var name: String
    public var icon: String
    public var displayStyle: String?
    public var sortOrder: Int
    /// Reserved for nested folders; always `nil` until nesting ships.
    public var parentFolderID: Int64?
    /// How content in this folder opens. `nil` defers to the per-feed setting.
    public var openMode: FeedOpenMode?
    /// Whether opening content here marks it read. `nil` defers to the default.
    public var marksReadOnOpen: Bool?
}
