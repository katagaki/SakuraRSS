import FoundationModels
import Hanami
import Observation
import SwiftUI
@preconcurrency import Translation

/// Summaries and translations for one piece of content, as the iOS viewers
/// offer them: cached in the database, a summary can itself be translated,
/// and either can be put back to the original.
@MainActor
@Observable
final class ContentAssistant {

    let article: Article
    let translatesTitle: Bool

    private(set) var summary: String?
    private(set) var translatedTitle: String?
    private(set) var translatedText: String?
    private(set) var translatedSummary: String?
    private(set) var isSummarizing = false
    private(set) var isTranslating = false
    private(set) var hasCachedSummary = false
    var showingSummary = false
    var showingTranslation = false
    var summaryError: String?
    var translationConfiguration: TranslationSession.Configuration?

    init(article: Article, translatesTitle: Bool) {
        self.article = article
        self.translatesTitle = translatesTitle
    }

    var isWorking: Bool { isSummarizing || isTranslating }
    var canSummarize: Bool { AppleIntelligenceAvailability.isAvailable }

    var hasTranslationForCurrentMode: Bool {
        showingSummary ? translatedSummary != nil : translatedText != nil
    }

    func displayTitle(original: String) -> String {
        guard showingTranslation, !showingSummary, let translatedTitle, !translatedTitle.isEmpty else {
            return original
        }
        return translatedTitle
    }

    func displayText(original: String?) -> String? {
        if showingSummary, let summary {
            return showingTranslation ? translatedSummary ?? summary : summary
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return original
    }

    func loadCached() async {
        let articleID = article.id
        let (translation, cachedSummary) = await Task.detached(priority: .userInitiated) {
            (
                try? DatabaseManager.shared.cachedArticleTranslation(for: articleID),
                try? DatabaseManager.shared.cachedArticleSummary(for: articleID)
            )
        }.value
        if let translation {
            translatedTitle = translation.title
            translatedText = translation.text
            translatedSummary = translation.summary
            showingTranslation = translation.title != nil || translation.text != nil
        }
        hasCachedSummary = !(cachedSummary ?? "").isEmpty
    }

    func toggleSummary(source: String?) {
        if summary != nil {
            withAnimation(.smooth.speed(2.0)) { showingSummary.toggle() }
            return
        }
        guard !isSummarizing else { return }
        Task {
            await summarize(source: source)
            if summary != nil {
                withAnimation(.smooth.speed(2.0)) { showingSummary = true }
            }
        }
    }

    func toggleTranslation() {
        if hasTranslationForCurrentMode && !isTranslating {
            withAnimation(.smooth.speed(2.0)) { showingTranslation.toggle() }
        } else if !isTranslating {
            if translationConfiguration == nil {
                translationConfiguration = .init()
            } else {
                translationConfiguration?.invalidate()
            }
        }
    }

    func showOriginal() {
        withAnimation(.smooth.speed(2.0)) {
            showingSummary = false
            showingTranslation = false
        }
    }

    func translate(with session: TranslationSession, source: String?) async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            if showingSummary, let summary, !summary.isEmpty {
                let response = try await session.translate(summary)
                translatedSummary = response.targetText
                try? DatabaseManager.shared.cacheTranslatedSummary(response.targetText, for: article.id)
            } else {
                let source = source ?? ""
                guard !ContentBlock.plainText(from: source).isEmpty else { return }
                let result = try await ContentBlock.translateArticleContent(
                    title: translatesTitle ? article.title : nil, markerText: source, session: session
                )
                translatedTitle = result.title
                translatedText = result.text
                try? DatabaseManager.shared.cacheArticleTranslation(
                    title: result.title, text: result.text, for: article.id
                )
            }
            withAnimation(.smooth.speed(2.0)) { showingTranslation = true }
        } catch {
            log("Translation", "failed: \(error)")
        }
    }

    private func summarize(source: String?) async {
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id), !cached.isEmpty {
            summary = cached
            return
        }
        let plainSource = ContentBlock.plainText(from: source ?? "")
        guard !plainSource.isEmpty else { return }
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            let instructions = String(localized: "Article.Summarize.Prompt", table: "Articles")
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: plainSource)
            summary = response.content
            hasCachedSummary = true
            try? DatabaseManager.shared.cacheArticleSummary(response.content, for: article.id)
        } catch {
            summaryError = error.localizedDescription
        }
    }
}
