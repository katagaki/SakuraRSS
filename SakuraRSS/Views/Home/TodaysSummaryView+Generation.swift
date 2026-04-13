import SwiftUI

extension TodaysSummaryView {

    static let batchCharLimit = 3000
    static let snippetCharLimit = 150

    func generateSummary(for date: Date) async {
        // Skip articles that are title-only, have empty/placeholder bodies,
        // or whose body is just the title repeated.  Removing these up
        // front means fewer LLM calls (lower energy) *and* a better
        // summary — the LLM has more signal to work with.
        let articles = feedManager.todaySummaryArticles().filter { article in
            BatchSummarizer.hasUsefulContent(title: article.title, summary: article.summary)
        }
        guard !articles.isEmpty else { return }

        if articles.count < 5 {
            withAnimation(.smooth.speed(2.0)) {
                summary = String(localized: "TodaysSummary.TooFew")
            }
            hasSummary = true
            return
        }

        isGenerating = true
        defer {
            isGenerating = false
            hasGenerated = true
        }

        let descriptions = articles.prefix(30).map { article -> String in
            let feed = feedManager.feed(forArticle: article)
            let source = feed?.title ?? ""
            let title = article.title
            let snippet = String((article.summary ?? "").prefix(Self.snippetCharLimit))
            return "[\(source)] \(title)\n\(snippet)"
        }

        let batches = BatchSummarizer.packBatches(descriptions, charLimit: Self.batchCharLimit)
        let instructions = String(localized: "TodaysSummary.PartialPrompt")
        let combineInstructions = String(localized: "TodaysSummary.CombinePrompt")

        do {
            let finalContent = try await BatchSummarizer.summarize(
                batches: batches,
                instructions: instructions,
                combineInstructions: combineInstructions
            )
            guard !finalContent.isEmpty else { return }

            withAnimation(.smooth.speed(2.0)) {
                summary = finalContent
            }
            hasSummary = true
            try? DatabaseManager.shared.cacheSummary(finalContent, ofType: .todaysSummary, for: date)
        } catch {
            generationFailed = true
            generationError = error.localizedDescription
        }
    }
}
