import AppIntents
import Foundation

struct ListEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("List", table: "AppIntents"))
    static let defaultQuery = ListEntityQuery()

    let id: String
    let listID: Int64
    let name: String

    init(list: FeedList) {
        self.id = String(list.id)
        self.listID = list.id
        self.name = list.name
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct ListEntityQuery: EntityStringQuery {

    func entities(for identifiers: [ListEntity.ID]) async throws -> [ListEntity] {
        let database = DatabaseManager.shared
        let identifierSet = Set(identifiers)
        let allLists = (try? database.allLists()) ?? []
        return allLists
            .filter { identifierSet.contains(String($0.id)) }
            .map(ListEntity.init(list:))
    }

    func entities(matching string: String) async throws -> [ListEntity] {
        let needle = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let allLists = (try? DatabaseManager.shared.allLists()) ?? []
        guard !needle.isEmpty else { return allLists.map(ListEntity.init(list:)) }
        return allLists
            .filter { $0.name.lowercased().contains(needle) }
            .map(ListEntity.init(list:))
    }

    func suggestedEntities() async throws -> [ListEntity] {
        let allLists = (try? DatabaseManager.shared.allLists()) ?? []
        return allLists.map(ListEntity.init(list:))
    }
}
