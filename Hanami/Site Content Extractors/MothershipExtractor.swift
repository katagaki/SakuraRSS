import Foundation
import SwiftSoup

public struct MothershipExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["mothership.sg"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let post = try? document.select("main[id^=post-]").first(),
              let content = try? post.select("div.content").first() else {
            return nil
        }

        _ = try? content.select("p:has(a[href*=bit.ly] > img)").remove()

        let featuredHTML = (try? post.select("div.image.featured").first()?.outerHtml()) ?? ""
        let contentHTML = (try? content.outerHtml()) ?? ""
        let combined = featuredHTML + contentHTML
        guard !combined.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: combined,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
