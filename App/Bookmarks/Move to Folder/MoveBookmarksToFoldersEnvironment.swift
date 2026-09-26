import SwiftUI

extension EnvironmentValues {
    /// Enabled only on Bookmarks surfaces, where saved content can be renamed,
    /// tagged, and organized into folders.
    @Entry var isBookmarksSurface: Bool = false
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
