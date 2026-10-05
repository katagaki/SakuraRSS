import Foundation

/// Zero-setup groupings that always reflect the library as it is now. They are
/// the organized-by-default half of Bookmarks; folders and tags are the half
/// the reader shapes themselves.
public nonisolated enum BookmarkSmartGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case unread
    case unsorted

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .all: "bookmark"
        case .unread: "circle.badge.checkmark"
        case .unsorted: "tray"
        }
    }
}
