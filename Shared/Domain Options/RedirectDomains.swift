import Foundation

/// Domains whose feed URLs should be rewritten to an alternative host before fetching.
nonisolated enum RedirectDomains {

    static let redirects: [String: String] = [
        "twitter.com": "x.com",
        "rsshub.app": "rsshub.rss3.workers.dev"
    ]

    static func redirectedURL(_ url: URL) -> URL {
        guard let host = url.host?.lowercased() else { return url }
        for (source, destination) in redirects {
            if host == source || host.hasSuffix(".\(source)") {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.host = destination
                return components?.url ?? url
            }
        }
        return url
    }
}
