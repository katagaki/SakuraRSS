import AppIntents
import Foundation

struct FeedEntity: AppEntity, Identifiable, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation =
        TypeDisplayRepresentation(name: LocalizedStringResource("Feed", table: "AppIntents"))
    static let defaultQuery = FeedEntityQuery()

    let id: String
    let feedID: Int64
    let title: String

    init(feed: Feed) {
        self.id = String(feed.id)
        self.feedID = feed.id
        self.title = feed.title
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }
}

struct FeedEntityQuery: EntityStringQuery {

    func entities(for identifiers: [FeedEntity.ID]) async throws -> [FeedEntity] {
        let database = DatabaseManager.shared
        let identifierSet = Set(identifiers)
        let allFeeds = (try? database.allFeeds()) ?? []
        return allFeeds
            .filter { identifierSet.contains(String($0.id)) }
            .map(FeedEntity.init(feed:))
    }

    func entities(matching string: String) async throws -> [FeedEntity] {
        let needle = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let allFeeds = (try? DatabaseManager.shared.allFeeds()) ?? []
        guard !needle.isEmpty else { return allFeeds.map(FeedEntity.init(feed:)) }
        return allFeeds
            .filter { $0.title.lowercased().contains(needle) }
            .map(FeedEntity.init(feed:))
    }

    func suggestedEntities() async throws -> [FeedEntity] {
        let allFeeds = (try? DatabaseManager.shared.allFeeds()) ?? []
        return allFeeds.map(FeedEntity.init(feed:))
    }
}
