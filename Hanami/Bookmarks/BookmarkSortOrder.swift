import Foundation

public nonisolated enum BookmarkSortOrder: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case title
    case site

    public static let storageKey = "Bookmarks.SortOrder"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .newest: "clock"
        case .oldest: "clock.arrow.circlepath"
        case .title: "textformat"
        case .site: "globe"
        }
    }
}
