import Foundation

extension YouTubePlaylistIntegration {

    /// Fetches the YouTube playlist page and parses the video list.
    func performFetch(url: URL) async -> YouTubePlaylistScrapeResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                print("[YouTubePlaylist] Could not decode response as UTF-8.")
                return YouTubePlaylistScrapeResult(videos: [], playlistTitle: nil)
            }

            guard let ytData = Self.extractYTInitialData(from: html) else {
                return YouTubePlaylistScrapeResult(videos: [], playlistTitle: nil)
            }

            let videos = Self.parsePlaylistVideos(from: ytData)
            let title = Self.parsePlaylistTitle(from: ytData)
            return YouTubePlaylistScrapeResult(videos: videos, playlistTitle: title)
        } catch {
            print("[YouTubePlaylist] Network request failed — \(error.localizedDescription)")
            return YouTubePlaylistScrapeResult(videos: [], playlistTitle: nil)
        }
    }
}
