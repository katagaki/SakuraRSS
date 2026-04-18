import Foundation
import SwiftSoup

/// GitHub READMEs, issues, and PR bodies live in well-known containers.
/// Using them directly avoids ambient repo-navigation chrome and side panels.
struct GitHubAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["github.com"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        let containerSelectors = [
            "#readme article",
            "article.markdown-body",
            ".markdown-body.entry-content",
            ".js-comment-body",
            ".comment-body"
        ]
        var htmlChunks: [String] = []
        for selector in containerSelectors {
            guard let elements = try? document.select(selector),
                  !elements.isEmpty() else { continue }
            for element in elements.prefix(6) {
                if let html = try? element.outerHtml(), !html.isEmpty {
                    htmlChunks.append(html)
                }
            }
            if !htmlChunks.isEmpty { break }
        }
        guard !htmlChunks.isEmpty else { return nil }
        let combined = htmlChunks.joined(separator: "\n")
        let text = ArticleExtractor.extractText(
            fromHTML: combined,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = ArticleExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
