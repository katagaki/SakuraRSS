import Foundation
import SwiftSoup

struct VergeAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["theverge.com"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select("#zephr-anchor").first(),
              let html = try? container.outerHtml(),
              !html.isEmpty else { return nil }

        let text = ArticleExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = ArticleExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
