import Foundation
import SwiftSoup

public struct France24Extractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["france24.com"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        let figureHTML = (try? document.select(".t-content__main-media figure").first()?
            .outerHtml()) ?? ""

        let contentHTML: String
        if let body = try? document.select(".t-content__body").first(),
           let html = try? body.outerHtml(), !html.isEmpty {
            contentHTML = html
        } else if let chapo = try? document.select(".t-content__chapo").first(),
                  let html = try? chapo.outerHtml(), !html.isEmpty {
            contentHTML = html
        } else {
            return nil
        }

        let combined = figureHTML + contentHTML
        let text = HTMLContentExtractor.extractText(
            fromHTML: combined,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
