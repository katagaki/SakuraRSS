import Foundation
import SwiftSoup

public nonisolated extension HTMLContentExtractor {

    /// Parsing a full article DOM takes seconds on large pages, so callers
    /// that live on the main actor must go through these wrappers to keep
    /// the work off the main thread.
    @concurrent
    static func extractText(
        offMainActorFromHTML html: String,
        baseURL: URL?,
        excludeTitle: String? = nil
    ) async -> String? {
        extractText(fromHTML: html, baseURL: baseURL, excludeTitle: excludeTitle)
    }

    @concurrent
    static func extractArticle(
        offMainActorFromHTML html: String,
        baseURL: URL?,
        excludeTitle: String? = nil
    ) async -> ExtractionResult {
        extractArticle(fromHTML: html, baseURL: baseURL, excludeTitle: excludeTitle)
    }

    @concurrent
    static func pageTitle(offMainActorFromHTML html: String) async -> String? {
        guard !html.isEmpty, let document = try? SwiftSoup.parse(html) else { return nil }
        return pageTitleFromDocument(document)
    }
}
