import Foundation
import SwiftSoup

/// Wikipedia articles are much cleaner when we extract the
/// `#mw-content-text > .mw-parser-output` container directly.
/// Auto-suggestions, navigation boxes, and citations all live
/// outside that scope or are easy to target with targeted selectors.
nonisolated struct WikipediaAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["wikipedia.org", "wikimedia.org"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let container = try? document.select(
            "#mw-content-text .mw-parser-output"
        ).first() else { return nil }

        let noiseSelectors = [
            ".infobox", ".navbox", ".metadata", ".hatnote",
            ".mw-editsection", ".reference", ".reflist",
            "#References", ".printfooter", ".mbox",
            ".shortdescription", ".sistersitebox"
        ]
        for selector in noiseSelectors {
            if let elements = try? container.select(selector) {
                _ = try? elements.remove()
            }
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
