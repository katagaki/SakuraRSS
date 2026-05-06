import AppIntents
import Foundation

struct GetLatestContentIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("GetLatestContent.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("GetLatestContent.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("GetLatestContent.Parameter.Feed", table: "AppIntents")
    )
    var feed: FeedEntity?

    @Parameter(
        title: LocalizedStringResource("GetLatestContent.Parameter.List", table: "AppIntents")
    )
    var list: ListEntity?

    @Parameter(
        title: LocalizedStringResource("GetLatestContent.Parameter.Topic", table: "AppIntents")
    )
    var topic: TopicPeopleEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Get latest content") {
            \.$feed
            \.$list
            \.$topic
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<ArticleEntity?> {
        let database = DatabaseManager.shared
        let article = try await Task.detached { () -> Article? in
            if let feedID = self.feed?.feedID {
                return (try? database.articles(forFeedID: feedID, limit: 1))?.first
            }
            if let listID = self.list?.listID {
                let feedIDs = (try? database.feedIDs(forListID: listID)) ?? []
                guard !feedIDs.isEmpty else { return nil }
                return (try? database.articles(forFeedIDs: feedIDs, limit: 1))?.first
            }
            if let topic = self.topic {
                return (try? database.articlesForEntity(
                    name: topic.name,
                    types: topic.entityTypes,
                    limit: 1
                ))?.first
            }
            return (try? database.allArticles(limit: 1))?.first
        }.value

        guard let article else {
            return .result(value: nil)
        }
        let feedTitle = try? database.feed(byID: article.feedID)?.title
        return .result(value: ArticleEntity(article: article, feedTitle: feedTitle))
    }
}
