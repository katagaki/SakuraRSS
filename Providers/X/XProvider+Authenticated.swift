import Foundation

extension XProvider {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("x.com") || domain.contains("twitter.com")
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["auth_token", "ct0"] }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://x.com/settings")
    }
}
