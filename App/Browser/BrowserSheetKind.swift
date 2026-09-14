import Foundation

/// Stacking two `.sheet(isPresented:)` modifiers on one view silently drops all
/// but the last, so the shell presents every sheet through a single item.
enum BrowserSheetKind: Identifiable {
    case bookmarks
    case addFeed(url: String)

    var id: String {
        switch self {
        case .bookmarks: "bookmarks"
        case .addFeed(let url): "addFeed:\(url)"
        }
    }
}
