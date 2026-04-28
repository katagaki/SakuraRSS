import Foundation
import WebKit

/// Manages Substack session cookies in Keychain and the `substack-feed://` URL scheme that marks
/// custom-domain Substack feeds detected via the RSS `<generator>` element.
enum SubstackAuth: Authenticated {

    /// Keychain-backed persistent cookie jar.
    nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.SubstackCookies"
    )

    /// Pseudo-scheme prepended to a feed URL once it is identified as Substack-powered.
    /// `https://example.com/feed` is stored as `substack-feed://example.com/feed`.
    nonisolated static let feedURLScheme = "substack-feed"

    // MARK: - Authenticated

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("substack.com")
    }

    /// Renders a `Cookie` header value from stored cookies whose domain matches `host`.
    nonisolated static func cookieHeader(for host: String) -> String? {
        guard let cookies = cookieStore.load() else { return nil }
        let target = host.lowercased()
        let matching = cookies.filter { cookie in
            let domain = cookie.domain.lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return target == domain || target.hasSuffix("." + domain)
        }
        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - Feed URL marker

    /// True when the URL string carries the Substack pseudo-scheme.
    nonisolated static func isWrappedFeedURL(_ urlString: String) -> Bool {
        urlString.hasPrefix(feedURLScheme + "://")
    }

    /// Replaces the URL's scheme with the Substack pseudo-scheme. Idempotent.
    nonisolated static func wrap(_ urlString: String) -> String {
        if isWrappedFeedURL(urlString) { return urlString }
        guard let range = urlString.range(of: "://") else { return urlString }
        return feedURLScheme + urlString[range.lowerBound...]
    }

    /// Restores the original `https` URL from a wrapped Substack feed URL.
    nonisolated static func unwrap(_ urlString: String) -> String {
        guard isWrappedFeedURL(urlString) else { return urlString }
        return "https" + urlString.dropFirst(feedURLScheme.count)
    }
}
