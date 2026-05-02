import Foundation

extension YouTubePlaylistFetcher {

    /// Concurrent fetch ceiling for per-video date lookups. Tuned to enrich a
    /// playlist quickly without tripping YouTube's anti-scraping heuristics.
    private static let videoDateConcurrency = 8

    func performFetch(url: URL, playlistID: String) async -> YouTubePlaylistFetchResult {
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let empty = YouTubePlaylistFetchResult(
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
                    if let atomDate = dates[video.videoId] {
                        copy.publishedDate = atomDate
                    }
                    return copy
                }
            }

            let videoIDsNeedingPreciseDate = videos
                .filter { dates[$0.videoId] == nil }
                .map(\.videoId)
            if !videoIDsNeedingPreciseDate.isEmpty {
                let preciseDates = await fetchVideoPagePublishDates(
                    videoIDs: videoIDsNeedingPreciseDate
                )
                if !preciseDates.isEmpty {
                    videos = videos.map { video in
                        var copy = video
                        if let date = preciseDates[video.videoId] {
                            copy.publishedDate = date
                        }
                        return copy
                    }
                }
            }

            return YouTubePlaylistFetchResult(
                videos: videos, playlistTitle: title, channelAvatarURL: avatarURL
            )
        } catch {
            print("[YouTubePlaylist] Network request failed - \(error.localizedDescription)")
            return empty
        }
    }

    private func fetchVideoPagePublishDates(videoIDs: [String]) async -> [String: Date] {
        await withTaskGroup(of: (String, Date?).self) { group in
            var results: [String: Date] = [:]
            var iterator = videoIDs.makeIterator()
            var inFlight = 0

            while inFlight < Self.videoDateConcurrency, let next = iterator.next() {
                group.addTask { (next, await self.fetchVideoPagePublishDate(videoID: next)) }
                inFlight += 1
            }

            while let (videoID, date) = await group.next() {
                if let date { results[videoID] = date }
                inFlight -= 1
                if let next = iterator.next() {
                    group.addTask { (next, await self.fetchVideoPagePublishDate(videoID: next)) }
                    inFlight += 1
                }
            }

            return results
        }
    }

    private func fetchVideoPagePublishDate(videoID: String) async -> Date? {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return Self.parseVideoPublishDate(fromHTML: html)
        } catch {
            return nil
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
