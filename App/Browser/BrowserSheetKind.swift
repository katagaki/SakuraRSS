import Foundation

/// Stacking two `.sheet(isPresented:)` modifiers on one view silently drops all
/// but the last, so the shell presents every sheet through a single item.
enum BrowserSheetKind: Identifiable {
    case addFeed(url: String)

    var id: String {
        switch self {
        case .addFeed(let url): "addFeed:\(url)"
        }
    }
}
