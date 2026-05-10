import Foundation

extension YouTubePlaylistProvider: MetadataProvider {

    nonisolated static func canFetchMetadata(for url: URL) -> Bool {
        isProfileURL(url)
    }

    static func fetchMetadata(for url: URL) async -> FetchedFeedMetadata? {
        guard let playlistID = extractIdentifier(from: url) else { return nil }
        let fetcher = YouTubePlaylistProvider()
        let result = await fetcher.fetchPlaylist(playlistID: playlistID)
        return FetchedFeedMetadata(
            displayName: result.playlistTitle,
            iconURL: result.channelAvatarURL.flatMap(URL.init(string:))
        )
    }
}
