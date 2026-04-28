import Foundation
import WebKit

/// Manages Substack session cookies in Keychain and the `substack-feed://` URL scheme that marks
/// custom-domain Substack feeds detected via the RSS `<generator>` element.
enum SubstackAuth {

    /// Keychain-backed persistent cookie jar.
    static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.SubstackCookies"
    )

    /// Pseudo-scheme prepended to a feed URL once it is identified as Substack-powered.
    /// `https://example.com/feed` is stored as `substack-feed://example.com/feed`.
    static let feedURLScheme = "substack-feed"

    // MARK: - Session

    static func hasSession() -> Bool {
        guard let cookies = cookieStore.load() else { return false }
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return domain == "substack.com" || domain.hasSuffix(".substack.com")
        }
    }

    /// Clears Substack cookies from Keychain and WKWebsiteDataStore.
    @MainActor
    static func clearSession() async {
        cookieStore.clear()

        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("substack.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }

    /// Exports Substack cookies from WKWebsiteDataStore to Keychain after login.
    @MainActor
    static func syncCookiesFromWebKit() async {
        let store = WKWebsiteDataStore.default()
        let allCookies = await store.httpCookieStore.allCookies()
        let substackCookies = allCookies.filter {
            $0.domain.lowercased().contains("substack.com")
        }
        guard !substackCookies.isEmpty else { return }
        cookieStore.save(substackCookies)

        #if DEBUG
        print("[SubstackAuth] Synced \(substackCookies.count) "
              + "cookies from WebKit → Keychain")
        #endif
    }

    /// Renders a `Cookie` header value from stored cookies whose domain matches `host`.
    static func cookieHeader(for host: String) -> String? {
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
    static func isWrappedFeedURL(_ urlString: String) -> Bool {
        urlString.hasPrefix(feedURLScheme + "://")
    }

    /// Replaces the URL's scheme with the Substack pseudo-scheme. Idempotent.
    static func wrap(_ urlString: String) -> String {
        if isWrappedFeedURL(urlString) { return urlString }
        guard let range = urlString.range(of: "://") else { return urlString }
        return feedURLScheme + urlString[range.lowerBound...]
    }

    /// Restores the original `https` URL from a wrapped Substack feed URL.
    static func unwrap(_ urlString: String) -> String {
        guard isWrappedFeedURL(urlString) else { return urlString }
        return "https" + urlString.dropFirst(feedURLScheme.count)
    }
}
