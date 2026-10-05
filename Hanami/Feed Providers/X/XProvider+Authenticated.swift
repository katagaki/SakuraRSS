import Foundation

public extension XProvider {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("x.com") || domain.contains("twitter.com")
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["auth_token", "ct0"] }

    /// Signed-out x.com still sets a guest `ct0`, so a session needs both
    /// cookies, matching what the GraphQL requests send.
    nonisolated static func hasSession() -> Bool {
        readXCookiesFromKeychain() != nil
    }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://x.com/settings")
    }
}
