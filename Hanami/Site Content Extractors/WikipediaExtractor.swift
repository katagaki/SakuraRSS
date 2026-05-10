import Foundation
import SwiftSoup

public struct WikipediaExtractor: SiteContentExtractor {

    public func canHandle(url: URL) -> Bool {
        matchesHost(url, ["wikipedia.org", "wikimedia.org"])
    }

    public func extract(
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

        let text = HTMLContentExtractor.extractText(
            fromHTML: html,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = HTMLContentExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
