import Foundation

struct HomeSectionBarItem: Identifiable, Hashable {
    let id: String
    let title: String
    let selection: HomeSelection

    func matches(_ other: HomeSelection) -> Bool {
        id == other.rawValue
    }
}
