import Foundation

struct HomeSectionBarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let selection: HomeSelection
    let listIconName: String?

    init(id: String, title: String, selection: HomeSelection, listIconName: String? = nil) {
        self.id = id
        self.title = title
        self.selection = selection
        self.listIconName = listIconName
    }

    func matches(_ other: HomeSelection) -> Bool {
        id == other.rawValue
    }
}
