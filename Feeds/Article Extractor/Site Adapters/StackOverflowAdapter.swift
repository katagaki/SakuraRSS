import Foundation
import SwiftSoup

/// Stack Overflow / Stack Exchange answer pages are better served by
/// concatenating the question body and the accepted / top answer body
/// than by letting the generic extractor grapple with the whole sidebar.
struct StackOverflowAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, [
            "stackoverflow.com", "stackexchange.com",
            "superuser.com", "serverfault.com", "askubuntu.com"
        ])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        var htmlParts: [String] = []
        if let question = try? document.select(
            ".question .post-text, .question .s-prose"
        ).first(),
           let html = try? question.outerHtml() {
            htmlParts.append("<h2>Question</h2>")
            htmlParts.append(html)
        }
        if let answers = try? document.select(
            ".answer .post-text, .answer .s-prose"
        ), !answers.isEmpty() {
            for (index, answer) in answers.prefix(3).enumerated() {
                if let html = try? answer.outerHtml() {
                    htmlParts.append("<h2>Answer \(index + 1)</h2>")
                    htmlParts.append(html)
                }
            }
        }
        guard !htmlParts.isEmpty else { return nil }
        let combined = htmlParts.joined(separator: "\n")
        let text = ArticleExtractor.extractText(
            fromHTML: combined,
            baseURL: baseURL,
            excludeTitle: excludeTitle
        )
        let metadata = ArticleExtractor.extractMetadata(from: document)
        return ExtractionResult(text: text, metadata: metadata)
    }
}
