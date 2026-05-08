import SwiftUI

extension DiscoverView {

    // MARK: - Data Loading

    // swiftlint:disable:next function_body_length
    func loadData() async {
        let database = DatabaseManager.shared
        let loadEntities = contentInsightsEnabled

        await Task.detached {
            let recent = (try? database.recentlyAccessedArticles()) ?? []

            var sections: [DiscoverEntitySection] = []
            var topics: [(name: String, count: Int)] = []
            var people: [(name: String, count: Int)] = []

            if loadEntities {
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

                topics = topTopics
                people = topPeople

                var sectionItems: [DiscoverEntitySection] = []
                for topic in topTopics.prefix(3) {
                    let articles = (try? database.articlesForEntity(
                        name: topic.name,
                        types: ["organization", "place"],
                        limit: 10
                    )) ?? []
                    if !articles.isEmpty {
                        sectionItems.append(DiscoverEntitySection(
                            name: topic.name,
                            types: ["organization", "place"],
                            articles: articles
                        ))
                    }
                }
                for person in topPeople.prefix(3) {
                    let articles = (try? database.articlesForEntity(
                        name: person.name,
                        types: ["person"],
                        limit: 10
                    )) ?? []
                    if !articles.isEmpty {
                        sectionItems.append(DiscoverEntitySection(
                            name: person.name,
                            types: ["person"],
                            articles: articles
                        ))
                    }
                }

                sectionItems = Self.dailyShuffled(sectionItems)
                sections = sectionItems
            }

            await MainActor.run {
                recentArticles = recent
                entitySections = sections
                allTopics = topics
                allPeople = people
            }
        }.value
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
