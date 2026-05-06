import SwiftUI

@MainActor
protocol ArticleActions {
    var article: Article { get }
    var isExtracting: Bool { get }
    var displayText: String? { get }
    var isAppleIntelligenceAvailable: Bool { get }

    var hasTranslationForCurrentMode: Bool { get }
    var hasTranslatedFullText: Bool { get }
    var isTranslating: Bool { get }
    var showingTranslation: Bool { get nonmutating set }

    var summarizedText: String? { get }
    var hasCachedSummary: Bool { get }
    var isSummarizing: Bool { get }
    var showingSummary: Bool { get nonmutating set }

    var includesArXivAction: Bool { get }
    var includesOpenLinkAction: Bool { get }

    func performTranslate()
    func performSummarize() async
    func performOpenArXivPDF()
}

extension ArticleActions {

    var includesArXivAction: Bool {
        ArXivProvider.pdfURL(forArticleURL: article.url) != nil
    }

    var includesOpenLinkAction: Bool {
        article.hasLink
    }

    func performOpenArXivPDF() {}
}
