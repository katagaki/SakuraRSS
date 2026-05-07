import AppIntents
import Foundation

struct SearchContentIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("SearchContent.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("SearchContent.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("SearchContent.Parameter.Keyword", table: "AppIntents")
    )
    var keyword: String

    @Parameter(
        title: LocalizedStringResource("SearchContent.Parameter.Limit", table: "AppIntents"),
        default: 25,
        inclusiveRange: (1, 200)
    )
    var limit: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Search content for \(\.$keyword)") {
            \.$limit
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[ArticleEntity]> {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .result(value: []) }
        let database = DatabaseManager.shared
        let cap = limit
        let entities = await Task.detached { () -> [ArticleEntity] in
            let results = (try? database.searchArticles(query: trimmed)) ?? []
            let feeds = (try? database.allFeeds()) ?? []
            let titlesByID = Dictionary(uniqueKeysWithValues: feeds.map { ($0.id, $0.title) })
            return results.prefix(cap).map { article in
                ArticleEntity(article: article, feedTitle: titlesByID[article.feedID])
            }
        }.value
        return .result(value: entities)
    }
}
