import Foundation
import SwiftSoup

/// A site-specific override for the generic article extractor.  Adapters
/// run before the generic pipeline; when one matches and returns a
/// non-nil result, the generic path is skipped.
protocol SiteAdapter {
    /// Called against the request URL (if available) and the document's
    /// canonical URL (if any) before parsing.  Hosts are matched with
    /// `hasSuffix` semantics so subdomains pass through by default.
    func canHandle(url: URL) -> Bool

    /// Extracts text + metadata from the parsed document.  Return `nil` to
    /// fall back to the generic pipeline.
    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult?
}

extension SiteAdapter {
    func matchesHost(_ url: URL, _ domains: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}

/// Central registry of adapters consulted by `ArticleExtractor`.
enum SiteAdapterRegistry {

    static let all: [SiteAdapter] = [
        WikipediaAdapter(),
        GitHubAdapter(),
        StackOverflowAdapter()
    ]

    static func adapter(for url: URL) -> SiteAdapter? {
        all.first { $0.canHandle(url: url) }
    }
}
