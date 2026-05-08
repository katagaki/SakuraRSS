import AppIntents
import Foundation

struct AddToBookmarksIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("AddToBookmarks.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("AddToBookmarks.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("AddToBookmarks.Parameter.Article", table: "AppIntents")
    )
    var article: ArticleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$article) to bookmarks")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let database = DatabaseManager.shared
        let changed = (try? database.setBookmarked(
            id: article.articleID,
            bookmarked: true
        )) ?? false
        return .result(value: changed)
    }
}
