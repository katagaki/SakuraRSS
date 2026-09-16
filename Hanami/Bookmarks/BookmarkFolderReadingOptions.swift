import Foundation

/// A folder's reading preferences. Each field is optional: `nil` keeps the
/// behaviour the content would have had outside Bookmarks.
public nonisolated struct BookmarkFolderReadingOptions: Hashable, Sendable {

    public var openMode: FeedOpenMode?
    public var marksReadOnOpen: Bool?

    public init(openMode: FeedOpenMode? = nil, marksReadOnOpen: Bool? = nil) {
        self.openMode = openMode
        self.marksReadOnOpen = marksReadOnOpen
    }
}
