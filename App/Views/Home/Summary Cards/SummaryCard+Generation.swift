import SwiftUI

extension SummaryCard {

    static let batchCharLimit = 3000
    static let snippetCharLimit = 150

    func generateSummary(for date: Date) async {
        let articles = kind.articles(in: feedManager).filter { article in
            BatchSummarizer.hasUsefulContent(title: article.title, summary: article.summary)
        }
        guard !articles.isEmpty else { return }

        if articles.count < 5 {
            withAnimation(.smooth.speed(2.0)) {
                summary = String(localized: kind.tooFew)
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
        let instructions = String(localized: "TodaysSummary.PartialPrompt", table: "Home")
        let combineInstructions = String(localized: "TodaysSummary.CombinePrompt", table: "Home")

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
            try? DatabaseManager.shared.cacheSummary(finalContent, ofType: kind.cacheType, for: date)
        } catch {
            generationFailed = true
            generationError = error.localizedDescription
        }
    }
}
