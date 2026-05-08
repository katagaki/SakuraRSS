import FoundationModels
import SwiftUI

extension NewYouTubePlayerView {

    func summarizeDescription() async {
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        let source = ContentBlock.plainText(from: descriptionSource ?? "")
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt", table: "Articles")

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
