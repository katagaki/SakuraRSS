import SwiftUI
import FoundationModels

extension ArticleDetailView {
    func summarizeArticle() async {
        let source = extractedText ?? article.summary ?? ""
        guard !source.isEmpty else { return }

        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt")
        let prompt = "\(instructions)\n\n\(source)"

        #if DEBUG
        debugPrint(prompt)
        #endif

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            summarizedText = response.content
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            // Summarization failed; user can retry
        }
    }
}
