import Foundation
import SwiftSoup

struct ZennAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["zenn.dev"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select(".znc").first() else {
            return nil
        }

        let html = (try? container.outerHtml()) ?? ""
        guard !html.isEmpty else { return nil }

        let text = ArticleExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = ArticleExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
