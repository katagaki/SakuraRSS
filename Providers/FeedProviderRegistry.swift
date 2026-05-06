import Foundation

/// Routes stored feed URLs and profile URLs to the correct `FeedProvider`.
nonisolated enum FeedProviderRegistry {

    static let all: [any FeedProvider.Type] = [
        XProvider.self,
        InstagramProvider.self,
        YouTubePlaylistProvider.self,
        SubstackProvider.self,
        NoteProvider.self,
        BlueskyProvider.self,
        RedditProvider.self,
        HackerNewsProvider.self,
        PixelfedProvider.self,
        ArXivProvider.self
    ]

    // MARK: - Convenience Fetchers

    static func metadataFetcher(forSiteURL url: URL) -> (any MetadataProvider.Type)? {
        for provider in all {
            if let metadata = provider as? any MetadataProvider.Type,
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

    /// Returns the `CommentsProvider` that can supply comments for `article`
    /// in `feed`, or `nil` if no provider matches.
    static func commentsProvider(
        for article: Article, in feed: Feed?
    ) -> (any CommentsProvider.Type)? {
        for provider in all {
            if let comments = provider as? any CommentsProvider.Type,
               comments.canProvideComments(for: article, in: feed) {
                return comments
            }
        }
        return nil
    }

    // MARK: - Legacy Auth Cookies

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
