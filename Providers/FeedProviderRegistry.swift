import Foundation

/// Central registry of `FeedProvider`-conforming services. Used to route
/// stored feed URLs and profile URLs to the correct provider without
/// scattering `if-else` chains across the codebase.
nonisolated enum FeedProviderRegistry {

    /// All registered providers, in URL-matching priority order.
    static let all: [any FeedProvider.Type] = [
        XProfileFetcher.self,
        InstagramProfileFetcher.self,
        YouTubePlaylistFetcher.self
    ]

    /// Returns the provider that owns a stored feed URL, regardless of flag state.
    static func provider(forFeedURL url: String) -> (any FeedProvider.Type)? {
        all.first { $0.matchesFeedURL(url) }
    }

    /// Returns the profile provider matching a public profile URL.
    static func profileProvider(forURL url: URL) -> (any ProfileFeedProvider.Type)? {
        for provider in all {
            if let profile = provider as? any ProfileFeedProvider.Type,
               profile.isProfileURL(url) {
                return profile
            }
        }
        return nil
    }

    /// Migrates WebKit cookies into Keychain for every enabled `Authenticated`
    /// provider. Called once at app launch.
    static func migrateAuthenticatedCookies() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in all where provider.isEnabled {
                guard let auth = provider as? any Authenticated.Type else { continue }
                group.addTask { @MainActor in
                    await auth.migrateWebKitCookiesIfNeeded()
                }
            }
        }
    }
}
