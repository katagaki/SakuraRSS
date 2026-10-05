import Foundation
import WebKit

/// Fetches Instagram profile posts via the web API using Keychain-stored session cookies.
@MainActor
public final class InstagramProvider: Authenticated {

    public nonisolated static var sessionService: ProviderSessionEvents.Service? { .instagram }

    public init() {}

    public nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    public static let webAppID = "936619743392459"

    public static let targetPostCount = 50

    private static var activeFetch: Task<InstagramProfileFetchResult, Error>?
    private static var activeFetchID: UUID?

    public nonisolated static let cookieStore = KeychainCookieStore(
        service: "com.tsubuzaki.SakuraRSS.InstagramCookies"
    )
    /// Fetches the most recent posts plus profile metadata. Concurrent calls are serialised.
    public func fetchProfile(profileURL: URL) async throws -> InstagramProfileFetchResult {
        let previousFetch = Self.activeFetch
        let fetchID = UUID()
        let task = Task {
            if let previousFetch { _ = await previousFetch.result }
            try Task.checkCancellation()
            return try await self.performFetch(profileURL: profileURL)
        }
        Self.activeFetch = task
        Self.activeFetchID = fetchID
        defer {
            if Self.activeFetchID == fetchID {
                Self.activeFetch = nil
                Self.activeFetchID = nil
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
    public nonisolated static func isInstagramHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "instagram.com" || host == "www.instagram.com"
    }

    public nonisolated static func isInstagramPostURL(_ url: URL) -> Bool {
        guard isInstagramHost(url.host) else { return false }
        let components = url.pathComponents
        return components.count >= 3
            && (components[1] == "p" || components[1] == "reel")
    }

    public nonisolated static func profileURL(for handle: String) -> URL? {
        URL(string: "https://www.instagram.com/\(handle)/")
    }
}
