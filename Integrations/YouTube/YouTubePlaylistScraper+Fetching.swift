import Foundation

extension YouTubePlaylistScraper {

    /// Fetches the playlist page and enriches each video with the Atom feed's publish date.
    /// Atom feed caps at ~15 entries, so older videos may lack a publish date.
    func performFetch(url: URL, playlistID: String) async -> YouTubePlaylistScrapeResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let empty = YouTubePlaylistScrapeResult(
            videos: [], playlistTitle: nil, channelAvatarURL: nil
        )

        do {
            async let atomDates = fetchAtomPublishDates(playlistID: playlistID)

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                print("[YouTubePlaylist] Could not decode response as UTF-8.")
                _ = await atomDates
                return empty
            }

            guard let ytData = Self.extractYTInitialData(from: html) else {
                _ = await atomDates
                return empty
            }

            var videos = Self.parsePlaylistVideos(from: ytData)
            let title = Self.parsePlaylistTitle(from: ytData)
            let avatarURL = Self.parseChannelAvatarURL(from: ytData)

            let dates = await atomDates
            if !dates.isEmpty {
                videos = videos.map { video in
                    var copy = video
                    copy.publishedDate = dates[video.videoId]
                    return copy
                }
            }

            return YouTubePlaylistScrapeResult(
                videos: videos, playlistTitle: title, channelAvatarURL: avatarURL
            )
        } catch {
            print("[YouTubePlaylist] Network request failed - \(error.localizedDescription)")
            return empty
        }
    }

    private func fetchAtomPublishDates(playlistID: String) async -> [String: Date] {
        guard let url = URL(
            string: "https://www.youtube.com/feeds/videos.xml?playlist_id=\(playlistID)"
        ) else { return [:] }

        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return [:] }
            return Self.parseAtomPublishDates(xml: xml)
        } catch {
            print("[YouTubePlaylist] Atom feed fetch failed - \(error.localizedDescription)")
            return [:]
        }
    }

    static func parseAtomPublishDates(xml: String) -> [String: Date] {
        var result: [String: Date] = [:]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        var searchRange = xml.startIndex..<xml.endIndex
        while let entryStart = xml.range(of: "<entry>", range: searchRange),
              let entryEnd = xml.range(
                of: "</entry>", range: entryStart.upperBound..<xml.endIndex
              ) {
            let entry = xml[entryStart.upperBound..<entryEnd.lowerBound]

            var videoID: String?
            if let idStart = entry.range(of: "<yt:videoId>"),
               let idEnd = entry.range(
                of: "</yt:videoId>", range: idStart.upperBound..<entry.endIndex
               ) {
                videoID = String(entry[idStart.upperBound..<idEnd.lowerBound])
            }

            var publishedDate: Date?
            if let pubStart = entry.range(of: "<published>"),
               let pubEnd = entry.range(
                of: "</published>", range: pubStart.upperBound..<entry.endIndex
               ) {
                let pubString = String(entry[pubStart.upperBound..<pubEnd.lowerBound])
                publishedDate = formatter.date(from: pubString)
                    ?? fallbackFormatter.date(from: pubString)
            }

            if let videoID, let publishedDate {
                result[videoID] = publishedDate
            }

            searchRange = entryEnd.upperBound..<xml.endIndex
        }
        return result
    }
}
