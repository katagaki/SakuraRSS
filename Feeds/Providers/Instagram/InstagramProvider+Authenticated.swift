import Foundation

extension InstagramProvider {

    nonisolated static func cookieDomainMatches(_ domain: String) -> Bool {
        domain.contains("instagram.com")
    }

    nonisolated static var sessionCookieNames: Set<String>? { ["sessionid", "ds_user_id"] }

    nonisolated static var cookieWarmURL: URL? {
        URL(string: "https://www.instagram.com/")
    }
}
