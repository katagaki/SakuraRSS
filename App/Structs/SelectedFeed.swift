import Foundation

enum SelectedFeed: Identifiable, Hashable {
    case add
    case edit(Int64)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let feedID): return "edit-\(feedID)"
        }
    }
}
