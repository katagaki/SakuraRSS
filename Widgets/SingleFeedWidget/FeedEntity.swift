import AppIntents

struct FeedQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [FeedEntity] {
        let database = DatabaseManager.shared
        let allFeeds = (try? database.allFeeds()) ?? []
        let idSet = Set(identifiers)
        return allFeeds
            .filter { idSet.contains(String($0.id)) }
            .map { FeedEntity(feedID: $0.id, title: $0.title) }
    }

    func suggestedEntities() async throws -> [FeedEntity] {
        let database = DatabaseManager.shared
        let allFeeds = (try? database.allFeeds()) ?? []
        return allFeeds.map { FeedEntity(feedID: $0.id, title: $0.title) }
    }

    func defaultResult() async -> FeedEntity? {
        let database = DatabaseManager.shared
        guard let first = (try? database.allFeeds())?.first else { return nil }
        return FeedEntity(feedID: first.id, title: first.title)
    }
}

struct FeedEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("SingleFeedWidget.Feed", table: "Widget"))
    static let defaultQuery = FeedQuery()

    var id: String
    var feedID: Int64
    var title: String

    init(feedID: Int64, title: String) {
        self.id = String(feedID)
        self.feedID = feedID
        self.title = title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}
