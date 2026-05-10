import Foundation
import SwiftSoup

struct TomsHardwareAdapter: SiteAdapter {

    func canHandle(url: URL) -> Bool {
        matchesHost(url, ["tomshardware.com"])
    }

    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult? {
        guard let body = try? document.select("#article-body").first() else {
            return nil
        }

        _ = try? body.select(noiseSelectors.joined(separator: ", ")).remove()

        guard let html = try? body.outerHtml(), !html.isEmpty else {
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

    /// Future plc CMS noise nested inside `#article-body`. `p.paywall` /
    /// `a.paywall` elements carry real body text (CSS hooks for the metered
    /// blur effect) and are deliberately left in place.
    private var noiseSelectors: [String] {
        [
            "#utility-bar",
            ".utility-bar",
            ".newsletter-form__wrapper",
            ".newsletter-inbodyContent-slice",
            ".slice-container",
            ".vanilla-image-block",
            ".xenforo-comment-widget",
            ".ad-unit",
            ".widget-ads",
            "#mid-article-leaderboard",
            "#top-leaderboard",
            ".widget-follow-us-on-google-news"
        ]
    }
}
