import SwiftUI

extension EnvironmentValues {
    /// Enabled only in the Bookmarks tab, where articles can be organized
    /// into bookmark folders via drag and drop, context menu, or swipe.
    @Entry var allowsMovingBookmarksToFolders: Bool = false
}

enum BookmarkDragPayload {
    private static let prefix = "sakura-bookmark:"

    static func encode(articleID: Int64) -> String {
        prefix + String(articleID)
    }

    static func decode(_ payload: String) -> Int64? {
        guard payload.hasPrefix(prefix) else { return nil }
        return Int64(payload.dropFirst(prefix.count))
    }
}
