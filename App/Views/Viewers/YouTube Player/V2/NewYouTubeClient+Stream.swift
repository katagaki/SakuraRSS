import Foundation

extension NewYouTubeClient {

    /// Extracts a YouTube video ID from a watch URL, short URL, or bare ID.
    static func parseVideoIdentifier(_ input: String) -> String? {
        let isValid: (Character) -> Bool = {
            $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-"
        }
        if input.count == 11, input.allSatisfy(isValid) { return input }
        if let components = URLComponents(string: input) {
            if let value = components.queryItems?.first(where: { $0.name == "v" })?.value {
                return value
            }
            if components.host?.contains("youtu.be") == true {
                let trimmed = components.path.trimmingCharacters(
                    in: CharacterSet(charactersIn: "/")
                )
                if trimmed.count == 11, trimmed.allSatisfy(isValid) {
                    return trimmed
                }
            }
            let segments = components.path.split(separator: "/", omittingEmptySubsequences: true)
            if segments.count >= 2, segments[0] == "shorts" {
                let candidate = String(segments[1])
                if candidate.count == 11, candidate.allSatisfy(isValid) {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Returns the HLS master URL for a given video. `AVPlayer` can play this
    /// URL directly without further parsing.
    func hlsMasterURL(videoId: String) async throws -> URL {
        let manifest = try await fetchPlayerResponse(videoId: videoId)
        guard
            let streamingData = manifest["streamingData"] as? [String: Any],
            let masterString = streamingData["hlsManifestUrl"] as? String,
            let masterURL = URL(string: masterString)
        else { throw YouTubeBrowseError.missingData }
        return masterURL
    }

    /// Fetches the HLS master playlist and picks the best video variant plus a
    /// matching audio media entry, useful when the caller wants to play video
    /// and audio on separate tracks.
    func resolveStreams(videoId: String) async throws -> YouTubeStreamSelection {
        let masterURL = try await hlsMasterURL(videoId: videoId)
        let masterText = try await fetchText(
            url: masterURL,
            headers: ["User-Agent": iosUserAgent]
        )
        let parsed = Self.parseHLSMaster(masterText)
        guard
            let video = Self.selectBestVideo(from: parsed.variants),
            let videoURL = URL(string: video.url)
        else { throw YouTubeBrowseError.missingData }
        let audioURL = Self.selectAudio(for: video, from: parsed.audios)
            .flatMap { URL(string: $0.url) }
        return YouTubeStreamSelection(
            videoVariantURL: videoURL,
            audioVariantURL: audioURL,
            resolution: video.resolution,
            bandwidth: video.bandwidth
        )
    }

    private func fetchPlayerResponse(videoId: String) async throws -> [String: Any] {
        let body: [String: Any] = ["context": iosContext(), "videoId": videoId]
        let data = try await post(endpoint: "player", body: body)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeBrowseError.decodingFailed
        }
        return json
    }

    private func fetchText(url: URL, headers: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YouTubeBrowseError.unexpectedResponse(status: http.statusCode)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw YouTubeBrowseError.decodingFailed
        }
        return text
    }
}
