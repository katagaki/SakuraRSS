import Foundation

public extension InstagramProvider {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain == "instagram.com" || domain.hasSuffix(".instagram.com")
    }

    nonisolated static func hasSession() -> Bool {
        getInstagramCookies() != nil
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["sessionid", "ds_user_id"] }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://www.instagram.com/")
    }
}
