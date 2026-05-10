import Foundation
import SwiftSoup

struct ZDNETAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["zdnet.com"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let body = try? document.select(".c-pageArticleSingle_body").first(),
              let html = try? body.outerHtml(), !html.isEmpty else {
            return nil
        }

        let text = ArticleExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = ArticleExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
