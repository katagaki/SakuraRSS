import Foundation

/// Routes stored feed URLs and profile URLs to the correct `FeedProvider`.
public nonisolated enum FeedProviderRegistry {

    public nonisolated(unsafe) static let all: [any FeedProvider.Type] = [
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

    public static func metadataFetcher(forSiteURL url: URL) -> (any MetadataProvider.Type)? {
        for provider in all {
            if let metadata = provider as? any MetadataProvider.Type,
               metadata.canFetchMetadata(for: url) {
                return metadata
            }
        }
        return nil
    }

    public static func provider(forFeedURL url: String) -> (any FeedProvider.Type)? {
        all.first { $0.matchesFeedURL(url) }
    }

    public static func profileProvider(forURL url: URL) -> (any ProfileFeedProvider.Type)? {
        for provider in all {
            if let profile = provider as? any ProfileFeedProvider.Type,
               profile.isProfileURL(url) {
                return profile
            }
        }
        return nil
    }

    public static func commentsProvider(
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

    @MainActor
    public static func migrateAuthenticatedCookies() async {
        let authenticatedProviders: [any Authenticated.Type] = all.compactMap { provider in
            guard provider.isEnabled, let auth = provider as? any Authenticated.Type else {
                return nil
            }
            return auth
        }
        for auth in authenticatedProviders {
            await auth.migrateWebKitCookiesIfNeeded()
        }
    }
}
