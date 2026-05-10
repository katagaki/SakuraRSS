import AppIntents
import Foundation
import Hanami

struct GetContentTextIntent: AppIntent {

    static let title: LocalizedStringResource =
        LocalizedStringResource("GetContentText.Title", table: "AppIntents")

    static let description: IntentDescription = IntentDescription(
        LocalizedStringResource("GetContentText.Description", table: "AppIntents")
    )

    @Parameter(
        title: LocalizedStringResource("GetContentText.Parameter.Article", table: "AppIntents")
    )
    var article: ArticleEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get text of \(\.$article)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let database = DatabaseManager.shared
        let articleID = article.articleID

        guard let storedArticle = try? database.article(byID: articleID) else {
            return .result(value: "")
        }

        let extractor = ContentResolver(article: storedArticle)
        let extracted = await extractor.extract()
        guard let text = extracted.text, !text.isEmpty else {
            return .result(value: "")
        }
        return .result(value: ContentBlock.plainText(from: text))
    }
}
