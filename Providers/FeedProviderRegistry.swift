import Foundation

/// Routes stored feed URLs and profile URLs to the correct `FeedProvider`.
nonisolated enum FeedProviderRegistry {

    static let all: [any FeedProvider.Type] = [
        XProfileFetcher.self,
        InstagramProfileFetcher.self,
        YouTubePlaylistFetcher.self,
        SubstackPublicationFetcher.self,
        NoteProfileFetcher.self,
        BlueskyProfileFetcher.self,
        RedditCommunityFetcher.self,
        HackerNewsProvider.self,
        PixelfedProfileFetcher.self
    ]

    static func metadataFetcher(forSiteURL url: URL) -> (any MetadataFetchingProvider.Type)? {
        for provider in all {
            if let metadata = provider as? any MetadataFetchingProvider.Type,
               metadata.canFetchMetadata(for: url) {
                return metadata
            }
        }
        return nil
    }

    static func provider(forFeedURL url: String) -> (any FeedProvider.Type)? {
        all.first { $0.matchesFeedURL(url) }
    }

    static func profileProvider(forURL url: URL) -> (any ProfileFeedProvider.Type)? {
        for provider in all {
            if let profile = provider as? any ProfileFeedProvider.Type,
               profile.isProfileURL(url) {
                return profile
            }
        }
        return nil
    }

    /// Migrates WebKit cookies to Keychain for every enabled `Authenticated` provider.
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
