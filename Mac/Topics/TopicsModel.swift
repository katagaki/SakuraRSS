import Foundation
import Hanami
import Observation

/// Loads the past week's topics and people, and content for the busiest
/// topics, the same way iOS's Today and Topics pages do.
@Observable
final class TopicsModel {

    struct TopicSection: Identifiable {
        let name: String
        let articles: [Article]
        var id: String { name }
    }

    private(set) var sections: [TopicSection] = []
    private(set) var topics: [(name: String, count: Int)] = []
    private(set) var people: [(name: String, count: Int)] = []
    private(set) var hasLoaded = false

    var isEmpty: Bool {
        sections.isEmpty && topics.isEmpty && people.isEmpty
    }

    func load() async {
        let loaded = await Task.detached(priority: .utility) {
            let database = DatabaseManager.shared
            let since = Date().addingTimeInterval(-7 * 24 * 3600)
            let topics = (try? database.topEntities(types: TopicKind.topic.entityTypes, since: since, limit: 50)) ?? []
            let people = (try? database.topEntities(type: "person", since: since, limit: 50)) ?? []
            let sections = topics.prefix(3).compactMap { topic -> TopicSection? in
                let articles = (try? database.articlesForEntity(
                    name: topic.name, types: TopicKind.topic.entityTypes, limit: 10
                )) ?? []
                return articles.isEmpty ? nil : TopicSection(name: topic.name, articles: articles)
            }
            return (sections, topics.filter { $0.count > 1 }, people.filter { $0.count > 1 })
        }.value
        sections = loaded.0
        topics = loaded.1
        people = loaded.2
        hasLoaded = true
    }
}
