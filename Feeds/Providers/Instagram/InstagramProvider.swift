import Foundation
import WebKit

/// Fetches Instagram profile posts via the web API using Keychain-stored session cookies.
final class InstagramProvider: Authenticated {

    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    static let webAppID = "936619743392459"

    static let targetPostCount = 50

    private static var activeFetch: Task<InstagramProfileFetchResult, Never>?

    nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.InstagramCookies"
    )

    // MARK: - Public

    /// Fetches the most recent posts plus profile metadata. Concurrent calls are serialised.
    func fetchProfile(profileURL: URL) async -> InstagramProfileFetchResult {
        if let existing = Self.activeFetch {
            _ = await existing.value
        }

        let task = Task {
            await self.performFetch(profileURL: profileURL)
        }
        Self.activeFetch = task
        let result = await task.value
        Self.activeFetch = nil
        return result
    }

    // MARK: - Static Helpers

    nonisolated static func isInstagramHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "instagram.com" || host == "www.instagram.com"
    }

    nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard isInstagramHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

    nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }
}
