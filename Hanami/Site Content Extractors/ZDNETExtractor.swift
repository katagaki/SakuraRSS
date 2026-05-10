import Foundation
import SwiftSoup

public struct ZDNETExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["zdnet.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let body = try? document.select(".c-pageArticleSingle_body").first(),
              let html = try? body.outerHtml(), !html.isEmpty else {
            return nil
        }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
