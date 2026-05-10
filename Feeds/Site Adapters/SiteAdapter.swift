import Foundation
import SwiftSoup

/// Site-specific override invoked before the generic extractor.
protocol SiteAdapter {
    func canHandle(url: URL) -> Bool

    /// Set to true when the site requires WebView-based fetching because
    /// content is dynamically loaded. Generic HTTP fetch is bypassed and
    /// the WebView-rendered HTML is fed to the standard text extractor.
    var requiresWebView: Bool { get }

    /// Returns extracted content, or nil to fall back to the generic pipeline.
    func extract(
        document: Document,
        baseURL: URL,
        excludeTitle: String?
    ) -> ExtractionResult?
}

extension SiteAdapter {
    var requiresWebView: Bool { false }

    func matchesHost(_ url: URL, _ domains: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return domains.contains { host == $0 || host.hasSuffix(".\($0)") }
    }
}
