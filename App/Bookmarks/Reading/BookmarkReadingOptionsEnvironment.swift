import SwiftUI
import Hanami

extension EnvironmentValues {
    /// Reading options of the folder each bookmark belongs to, resolved once per
    /// Bookmarks surface so routing a tap costs no database lookup.
    @Entry var bookmarkReadingOptions: [Int64: BookmarkFolderReadingOptions] = [:]
}
