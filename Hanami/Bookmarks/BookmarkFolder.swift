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

    public init(
        id: Int64,
        name: String,
        icon: String,
        displayStyle: String? = nil,
        sortOrder: Int = 0,
        parentFolderID: Int64? = nil,
        openMode: FeedOpenMode? = nil,
        marksReadOnOpen: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.displayStyle = displayStyle
        self.sortOrder = sortOrder
        self.parentFolderID = parentFolderID
        self.openMode = openMode
        self.marksReadOnOpen = marksReadOnOpen
    }
}
