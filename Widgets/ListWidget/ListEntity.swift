import AppIntents

struct ListQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [ListEntity] {
        let database = DatabaseManager.shared
        let allLists = (try? database.allLists()) ?? []
        let idSet = Set(identifiers)
        return allLists
            .filter { idSet.contains(String($0.id)) }
            .map { ListEntity(listID: $0.id, title: $0.name) }
    }

    func suggestedEntities() async throws -> [ListEntity] {
        let database = DatabaseManager.shared
        let allLists = (try? database.allLists()) ?? []
        return allLists.map { ListEntity(listID: $0.id, title: $0.name) }
    }

    func defaultResult() async -> ListEntity? {
        let database = DatabaseManager.shared
        guard let first = (try? database.allLists())?.first else { return nil }
        return ListEntity(listID: first.id, title: first.name)
    }
}

struct ListEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("ListWidget.List", table: "Widget"))
    static var defaultQuery = ListQuery()

    var id: String
    var listID: Int64
    var title: String

    init(listID: Int64, title: String) {
        self.id = String(listID)
        self.listID = listID
        self.title = title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
