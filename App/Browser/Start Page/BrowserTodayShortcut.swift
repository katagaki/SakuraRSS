import SwiftUI
import Hanami

/// The four places Today opens onto. A grid rather than a list: they are
/// destinations of equal weight, not a ranking.
enum BrowserTodayShortcut: String, CaseIterable, Identifiable {
    case following
    case allContent
    case bookmarks
    case topics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .following: String(localized: "Tabs.Feeds")
        case .allContent: String(localized: "Location.AllContent", table: "Browser")
        case .bookmarks: String(localized: "Location.Bookmarks", table: "Browser")
        case .topics: String(localized: "Location.Topics", table: "Browser")
        }
    }

    var symbolName: String {
        switch self {
        case .following: "dot.radiowaves.up.forward"
        case .allContent: "tray.full"
        case .bookmarks: "bookmark"
        case .topics: "number"
        }
    }

    /// Tints the icon tile the way a list's icon tints its own in Following.
    var tint: Color {
        switch self {
        case .following: .blue
        case .allContent: .orange
        case .bookmarks: .pink
        case .topics: .purple
        }
    }
}
