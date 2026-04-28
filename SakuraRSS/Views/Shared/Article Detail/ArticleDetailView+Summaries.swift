import SwiftUI
import FoundationModels

extension ArticleDetailView {
    func summarizeArticle() async {
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        let source = ContentBlock.plainText(from: extractedText ?? article.summary ?? "")
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt", table: "Articles")

        #if DEBUG
        debugPrint("Article summary prompt:\n\(instructions)\n\n\(source)")
        #endif

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: source)
            summarizedText = response.content
            if !article.isEphemeral {
                try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
            }
        } catch {
            summarizationError = error.localizedDescription
        }
    }
}
