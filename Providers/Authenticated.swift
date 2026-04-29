import Foundation
import WebKit

/// A type that owns a Keychain-backed cookie jar and bridges it to
/// `WKWebsiteDataStore`. Conformers declare the cookie store, the domain
/// match for filtering WebKit cookies, and (optionally) the cookie names
/// that signal a logged-in session.
///
/// The protocol provides default implementations for `hasSession`,
/// `clearSession`, `syncCookiesFromWebKit`, and `migrateWebKitCookiesIfNeeded`.
protocol Authenticated {

    /// Keychain-backed persistent cookie jar.
    nonisolated static var cookieStore: KeychainCookieStore { get }

    /// True for cookies that belong to this service. Used to filter
    /// `WKHTTPCookieStore.allCookies()` during sync, clear, and migration.
    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool

    /// If non-nil, `hasSession()` requires at least one persisted cookie
    /// whose name is in this set. If `nil`, any persisted cookie matching
    /// `cookieDomainMatches` is sufficient.
    nonisolated static var sessionCookieNames: Set<String>? { get }

    /// URL loaded in a transient `WKWebView` to coax WebKit into restoring
    /// its on-disk cookie jar before migration. `nil` skips warming
    /// (used by services that never had a WebKit-only era).
    nonisolated static var cookieWarmURL: URL? { get }

    /// Optional hook called at the end of `clearSession` for service-specific
    /// state (e.g. cached query IDs).
    @MainActor
    static func didClearSession() async

    nonisolated static func hasSession() -> Bool

    @MainActor
    static func clearSession() async

    @MainActor
    static func syncCookiesFromWebKit() async

    @MainActor
    static func migrateWebKitCookiesIfNeeded() async
}

extension Authenticated {

    nonisolated static var sessionCookieNames: Set<String>? { nil }
    nonisolated static var cookieWarmURL: URL? { nil }

    @MainActor
    static func didClearSession() async {}

    nonisolated static func hasSession() -> Bool {
        guard let cookies = cookieStore.load() else { return false }
        if let names = sessionCookieNames {
            return cookies.contains { names.contains($0.name) }
        }
        return cookies.contains { cookieDomainMatches($0.domain.lowercased()) }
    }

    @MainActor
    static func clearSession() async {
        cookieStore.clear()
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookieDomainMatches(cookie.domain.lowercased()) {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        await didClearSession()
    }

    @MainActor
    static func syncCookiesFromWebKit() async {
        let store = WKWebsiteDataStore.default()
        let allCookies = await store.httpCookieStore.allCookies()
        let matching = allCookies.filter { cookieDomainMatches($0.domain.lowercased()) }
        guard !matching.isEmpty else { return }
        cookieStore.save(matching)

        log("\(String(describing: Self.self))", "Synced \(matching.count) cookies from WebKit → Keychain")
    }

    @MainActor
    static func migrateWebKitCookiesIfNeeded() async {
        if cookieStore.load() != nil { return }
        await warmCookieStore()
        await syncCookiesFromWebKit()
    }

    @MainActor
    static func warmCookieStore() async {
        guard let url = cookieWarmURL else { return }
        let key = "Authenticated.warmed.\(String(describing: Self.self))"
        if AuthenticatedWarmRegistry.isWarmed(key) { return }
        AuthenticatedWarmRegistry.markWarmed(key)

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = sakuraUserAgent
        webView.load(URLRequest(url: url, timeoutInterval: 10))
        try? await Task.sleep(for: .seconds(2))
    }
}

/// Tracks per-conformer warm state for the `Authenticated` default warming.
@MainActor
private enum AuthenticatedWarmRegistry {
    private static var warmed: Set<String> = []
    static func isWarmed(_ key: String) -> Bool { warmed.contains(key) }
    static func markWarmed(_ key: String) { warmed.insert(key) }
}
