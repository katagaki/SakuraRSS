import Foundation

/// Parsed video from a YouTube playlist page.
struct ParsedPlaylistVideo: Sendable {
    let videoId: String
    let title: String
    let thumbnailURL: String
}

/// Result of scraping a YouTube playlist.
struct YouTubePlaylistScrapeResult: Sendable {
    let videos: [ParsedPlaylistVideo]
    let playlistTitle: String?
}

/// Fetches videos from a YouTube playlist by scraping the playlist page HTML.
/// No login required — playlists are public.
final class YouTubePlaylistIntegration: Integration {

    // MARK: - Integration overrides

    override class var feedURLScheme: String { YouTubePlaylistURLHelpers.feedURLScheme }

    override func scrape(identifier: String) async -> IntegrationScrapeResult {
        let result = await scrapePlaylist(playlistID: identifier)

        let articles = result.videos.map { video in
            ArticleInsertItem(
                title: video.title,
                url: "https://www.youtube.com/watch?v=\(video.videoId)",
                data: ArticleInsertData(
                    imageURL: video.thumbnailURL
                )
            )
        }

        return IntegrationScrapeResult(
            articles: articles,
            feedTitle: result.playlistTitle,
            profileImageURL: nil
        )
    }

    // MARK: - Public

    /// Fetches videos from the given YouTube playlist.
    func scrapePlaylist(playlistID: String) async -> YouTubePlaylistScrapeResult {
        guard let url = YouTubePlaylistURLHelpers.playlistURL(for: playlistID) else {
            return YouTubePlaylistScrapeResult(videos: [], playlistTitle: nil)
        }
        return await performFetch(url: url)
    }
}
