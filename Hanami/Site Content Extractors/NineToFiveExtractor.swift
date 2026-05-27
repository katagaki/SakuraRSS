import Foundation
import SwiftSoup

public struct NineToFiveExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["9to5mac.com", "9to5google.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        let metadata = HTMLContentExtractor.extractMetadata(from: document)

        guard let container = try? document.select("div.post-content").first() else {
            return nil
        }
        // The body lives in `.post-content`; every `<article>` on the page is a
        // clickable recirculation card, so the generic `article` selector would
        // otherwise return a "Featured Content" carousel item. Strip those cards
        // in case they nest inside the body container.
        try? container.select(".featured-items, .related-guides, .related-guide").remove()

        guard let html = try? container.outerHtml(), !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        guard text?.isEmpty == false else { return nil }
        return ExtractionResult(text: text, metadata: metadata)
    }
}
