import Foundation
import SwiftSoup

public struct ZennExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["zenn.dev"])
    }

    public func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select(".znc").first() else {
            return nil
        }

        let html = (try? container.outerHtml()) ?? ""
        guard !html.isEmpty else { return nil }

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
