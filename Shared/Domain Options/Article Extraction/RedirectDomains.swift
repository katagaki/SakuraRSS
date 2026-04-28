import Foundation

/// Domains whose feed URLs should be rewritten to an alternative host before fetching.
nonisolated enum RedirectDomains: DomainExceptions {

    static let redirects: [String: String] = [
        "twitter.com": "x.com",
        "rsshub.app": "rsshub.rss3.workers.dev"
    ]

    static var exceptionDomains: Set<String> { Set(redirects.keys) }

    static func redirectedURL(_ url: URL) -> URL {
        guard let source = matchedDomain(for: url),
              let destination = redirects[source] else { return url }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = destination
        return components?.url ?? url
    }
}
