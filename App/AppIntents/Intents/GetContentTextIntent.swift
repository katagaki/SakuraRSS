import AppIntents
import Foundation

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
    func perform() async throws -> some IntentResult & ReturnsValue<[ContentBlockEntity]> {
        let database = DatabaseManager.shared
        let articleID = article.articleID

        guard let storedArticle = try? database.article(byID: articleID) else {
            return .result(value: [])
        }

        if let cached = try? database.cachedArticleContent(for: articleID),
           !cached.isEmpty {
            let blocks = ContentBlock.parse(cached).map(ContentBlockEntity.init(block:))
            return .result(value: blocks)
        }

        if let raw = storedArticle.content, !raw.isEmpty,
           let text = ArticleExtractor.extractText(
            fromHTML: raw,
            baseURL: URL(string: storedArticle.url),
            excludeTitle: storedArticle.title
           ),
           !text.isEmpty {
            let blocks = ContentBlock.parse(text).map(ContentBlockEntity.init(block:))
            return .result(value: blocks)
        }

        if let articleURL = URL(string: storedArticle.url),
           let text = await ArticleExtractor.extractText(
            fromURL: articleURL,
            excludeTitle: storedArticle.title
           ),
           !text.isEmpty {
            try? database.cacheArticleContent(text, for: articleID)
            let blocks = ContentBlock.parse(text).map(ContentBlockEntity.init(block:))
            return .result(value: blocks)
        }

        return .result(value: [])
    }
}
