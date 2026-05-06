import AppIntents
import Foundation

struct TopicPeopleQuery: EntityStringQuery {

    private static let lookbackDays: Double = 7
    private static let suggestionLimit = 30

    func entities(for identifiers: [TopicPeopleEntity.ID]) async throws -> [TopicPeopleEntity] {
        let suggestions = await loadAll(limit: 200)
        let identifierSet = Set(identifiers)
        return suggestions.filter { identifierSet.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [TopicPeopleEntity] {
        let needle = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestions = await loadAll(limit: 200)
        guard !needle.isEmpty else { return Array(suggestions.prefix(Self.suggestionLimit)) }
        return suggestions
            .filter { $0.name.lowercased().contains(needle) }
            .prefix(Self.suggestionLimit)
            .map { $0 }
    }

    func suggestedEntities() async throws -> [TopicPeopleEntity] {
        await loadAll(limit: Self.suggestionLimit)
    }

    /// Pulls topics and people from the NLP cache merged into a single list,
    /// sorted by mention count desc.
    static func loadTop(limit: Int) async -> [TopicPeopleEntity] {
        await loadInternal(limit: limit)
    }

    private func loadAll(limit: Int) async -> [TopicPeopleEntity] {
        await Self.loadInternal(limit: limit)
    }

    private static func loadInternal(limit: Int) async -> [TopicPeopleEntity] {
        let database = DatabaseManager.shared
        let cutoff = Date().addingTimeInterval(-lookbackDays * 24 * 3600)
        return await Task.detached { () -> [TopicPeopleEntity] in
            let topics = (try? database.topEntities(
                types: ["organization", "place"],
                since: cutoff,
                limit: limit
            )) ?? []
            let people = (try? database.topEntities(
                type: "person",
                since: cutoff,
                limit: limit
            )) ?? []
            let merged = topics.map { TopicPeopleEntity(kind: .topic, name: $0.name, count: $0.count) }
                + people.map { TopicPeopleEntity(kind: .person, name: $0.name, count: $0.count) }
            return merged
                .sorted { $0.count > $1.count }
                .prefix(limit)
                .map { $0 }
        }.value
    }
}
