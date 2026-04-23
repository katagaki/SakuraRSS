import Foundation
import SwiftSoup

/// Site-specific override invoked before the generic extractor.
protocol SiteAdapter {
    func canHandle(url: URL) -> Bool

    /// Returns extracted content, or nil to fall back to the generic pipeline.
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
