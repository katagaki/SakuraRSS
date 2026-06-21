import Foundation
import SwiftUI
import Hanami

extension SummarySection {

    func generateHeadlines(for date: Date) async {
        await MainActor.run { isGenerating = true }

        let generator = SummaryHeadlineGenerator(kind: kind, feedManager: feedManager)
        switch await generator.generate(for: date) {
        case .noContent:
            await markNoContentAvailable()
        case .failed(let error):
            await markGenerationFailed(error: error)
        case .generated(let resolved, let partial, let count):
            await applyGenerated(
                resolved,
                for: date,
                partialGeneration: partial,
                articleCountAtGeneration: count
            )
        }
    }

    private func applyGenerated(
        _ resolved: [SummaryHeadline],
        for date: Date,
        partialGeneration: Bool,
        articleCountAtGeneration: Int
    ) async {
        await MainActor.run {
            isGenerating = false
            hasGenerated = true
            guard !resolved.isEmpty else {
                generationFailed = true
                generationError = String(localized: "SummaryHeadlines.NoEventsExtracted", table: "Home")
                return
            }
            withAnimation(.smooth.speed(2.0)) { headlines = resolved }
            hasSummary = true
            cachedIsPartial = partialGeneration
            cachedArticleCountAtGeneration = articleCountAtGeneration
        }
    }

    private func markGenerationFailed(error: Error?) async {
        await MainActor.run {
            isGenerating = false
            hasGenerated = true
            generationFailed = true
            if let error {
                generationError = error.localizedDescription
            } else {
                generationError = String(localized: "SummaryHeadlines.NoEventsExtracted", table: "Home")
            }
        }
    }

    /// Flips the section into the "no content" ContentUnavailableView state
    /// when no eligible articles exist (no feeds, all filtered out, or fewer
    /// than the minimum). Without this, the placeholder would spin forever.
    private func markNoContentAvailable() async {
        await MainActor.run {
            isGenerating = false
            hasGenerated = true
            generationFailed = true
            generationError = String(localized: "SummaryHeadlines.NoEventsExtracted", table: "Home")
        }
    }
}
