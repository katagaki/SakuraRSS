import SwiftUI
import FoundationModels

extension PodcastEpisodeView {
    func summarizeArticle() async {
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        let source = article.summary ?? ""
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt")

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: source)
            summarizedText = response.content
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            summarizationError = error.localizedDescription
        }
    }
}
