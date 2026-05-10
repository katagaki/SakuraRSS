import SwiftUI
import Hanami

extension DiscoverView {

    // MARK: - Data Loading

    func loadData() async {
        let database = DatabaseManager.shared
        let loadEntities = contentInsightsEnabled

        await Task.detached {
            let recent = (try? database.recentlyAccessedArticles()) ?? []
            let entityData = loadEntities ? Self.loadEntityData(database: database) : .empty

            await MainActor.run {
                recentArticles = recent
                entitySections = entityData.sections
                allTopics = entityData.topics
                allPeople = entityData.people
            }
        }.value
    }

    nonisolated static func loadEntityData(database: DatabaseManager) -> DiscoverEntityData {
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        let topTopics = (try? database.topEntities(
            types: ["organization", "place"],
            since: sevenDaysAgo,
            limit: 50
        )) ?? []
        let topPeople = (try? database.topEntities(
            type: "person",
            since: sevenDaysAgo,
            limit: 50
        )) ?? []

        var sectionItems: [DiscoverEntitySection] = []
        sectionItems.append(contentsOf: buildSections(
            from: topTopics.prefix(3),
            types: ["organization", "place"],
            database: database
        ))
        sectionItems.append(contentsOf: buildSections(
            from: topPeople.prefix(3),
            types: ["person"],
            database: database
        ))

        return DiscoverEntityData(
            sections: dailyShuffled(sectionItems),
            topics: topTopics,
            people: topPeople
        )
    }

    nonisolated static func buildSections(
        from entities: ArraySlice<(name: String, count: Int)>,
        types: [String],
        database: DatabaseManager
    ) -> [DiscoverEntitySection] {
        entities.compactMap { entity in
            let articles = (try? database.articlesForEntity(
                name: entity.name,
                types: types,
                limit: 10
            )) ?? []
            guard !articles.isEmpty else { return nil }
            return DiscoverEntitySection(
                name: entity.name,
                types: types,
                articles: articles
            )
        }
    }

    // MARK: - Daily Deterministic Shuffle

    nonisolated static func dailyShuffled(_ items: [DiscoverEntitySection]) -> [DiscoverEntitySection] {
        guard items.count > 1 else { return items }
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let year = calendar.component(.year, from: Date())
        var rng = DailyRNG(seed: UInt64(year * 1000 + day))
        var result = items
        result.shuffle(using: &rng)
        return result
    }
}
