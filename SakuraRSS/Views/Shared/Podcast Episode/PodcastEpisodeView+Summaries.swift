import SwiftUI
import FoundationModels

extension PodcastEpisodeView {
    func summarizeArticle() async {
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            summarizedText = cached
            return
        }

        // Prefer the full transcript when available - summarizing actual episode content
        // produces far better results than the RSS feed's short description.
        let transcriptText = transcript?
            .map(\.text)
            .joined(separator: " ") ?? ""
        let useTranscript = !transcriptText.isEmpty

        let source = useTranscript ? transcriptText : (article.summary ?? "")
        guard !source.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        let instructions = String(localized: "Article.Summarize.Prompt", table: "Articles")

        do {
            let summary: String
            if useTranscript {
                // Full transcripts can easily exceed the language model's context window.
                // Use the existing BatchSummarizer to chunk, summarize concurrently, then combine.
                let charLimit = 6000
                let sentences = source
                    .split(whereSeparator: { ".!?".contains($0) })
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let batches = BatchSummarizer.packBatches(sentences, charLimit: charLimit)
                summary = try await BatchSummarizer.summarize(
                    batches: batches,
                    instructions: instructions,
                    combineInstructions: instructions
                )
            } else {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(to: source)
                summary = response.content
            }
            summarizedText = summary
            try? DatabaseManager.shared.cacheArticleSummary(summary, for: article.id)
        } catch {
            summarizationError = error.localizedDescription
        }
    }
}
