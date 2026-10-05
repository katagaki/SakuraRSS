import Foundation

/// Records how far preview lookup got for a bookmark, so a page that has no
/// preview image isn't re-fetched on every launch.
public nonisolated enum BookmarkPreviewFetchState: Int, Sendable {
    case notAttempted = 0
    case resolved = 1
    case unavailable = 2
}
