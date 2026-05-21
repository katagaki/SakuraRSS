import Foundation
import Hanami

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

    /// Resolves how a video should be played. Live and legacy responses still
    /// expose `hlsManifestUrl`, which `AVPlayer` can play directly. Newer
    /// responses only expose `adaptiveFormats`, which are repackaged into a
    /// locally served HLS stream.
    func resolvePlaybackSource(videoId: String) async throws -> YouTubePlaybackSource {
        let manifest = try await fetchPlayerResponse(videoId: videoId)
        guard let streamingData = manifest["streamingData"] as? [String: Any] else {
            Self.logManifestDiagnostics(videoId: videoId, manifest: manifest)
            throw YouTubeBrowseError.missingData
        }
        if let manifestString = streamingData["hlsManifestUrl"] as? String,
           let manifestURL = URL(string: manifestString) {
            return .remoteHLS(manifestURL)
        }
        if let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]],
           !adaptiveFormats.isEmpty {
            return .localHLS(try await buildLocalHLSStream(from: adaptiveFormats, videoId: videoId))
        }
        Self.logManifestDiagnostics(videoId: videoId, manifest: manifest)
        throw YouTubeBrowseError.missingData
    }

    /// Returns the HLS playlist URL for a given video. `AVPlayer` can play this
    /// URL directly without further parsing.
    func hlsPlaylistURL(videoId: String) async throws -> URL {
        let manifest = try await fetchPlayerResponse(videoId: videoId)
        guard
            let streamingData = manifest["streamingData"] as? [String: Any],
            let manifestString = streamingData["hlsManifestUrl"] as? String,
            let manifestURL = URL(string: manifestString)
        else {
            Self.logManifestDiagnostics(videoId: videoId, manifest: manifest)
            throw YouTubeBrowseError.missingData
        }
        return manifestURL
    }

    private static func logManifestDiagnostics(videoId: String, manifest: [String: Any]) {
        let topLevelKeys = manifest.keys.sorted().joined(separator: ", ")
        log("YouTube", "Diag \(videoId) topLevelKeys: \(topLevelKeys)")

        if let playabilityStatus = manifest["playabilityStatus"] as? [String: Any] {
            let status = playabilityStatus["status"] as? String ?? "(none)"
            let reason = playabilityStatus["reason"] as? String ?? "(none)"
            let playabilityKeys = playabilityStatus.keys.sorted().joined(separator: ", ")
            log("YouTube", "Diag \(videoId) playability status=\(status) reason=\(reason) keys=\(playabilityKeys)")
            if let errorScreen = playabilityStatus["errorScreen"] as? [String: Any] {
                let errorKeys = errorScreen.keys.sorted().joined(separator: ", ")
                log("YouTube", "Diag \(videoId) errorScreen keys=\(errorKeys)")
            }
        } else {
            log("YouTube", "Diag \(videoId) no playabilityStatus")
        }

        if let streamingData = manifest["streamingData"] as? [String: Any] {
            let streamingKeys = streamingData.keys.sorted().joined(separator: ", ")
            let formatCount = (streamingData["formats"] as? [Any])?.count ?? 0
            let adaptiveCount = (streamingData["adaptiveFormats"] as? [Any])?.count ?? 0
            let hasHLS = streamingData["hlsManifestUrl"] != nil
            let hasDash = streamingData["dashManifestUrl"] != nil
            let serverAbrStreamingUrl = streamingData["serverAbrStreamingUrl"] != nil
            // swiftlint:disable:next line_length
            log("YouTube", "Diag \(videoId) streamingData keys=\(streamingKeys) formats=\(formatCount) adaptive=\(adaptiveCount) hls=\(hasHLS) dash=\(hasDash) serverAbr=\(serverAbrStreamingUrl)")
        } else {
            log("YouTube", "Diag \(videoId) no streamingData")
        }

        if let json = try? JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        ), let text = String(data: json, encoding: .utf8) {
            let limit = 4096
            let truncated = text.count > limit
                ? String(text.prefix(limit)) + "...(truncated \(text.count - limit) chars)"
                : text
            log("YouTube", "Diag \(videoId) response body:\n\(truncated)")
        }
    }

    /// Fetches the HLS multivariant playlist and picks the best video variant
    /// plus a matching audio media entry, useful when the caller wants to play
    /// video and audio on separate tracks.
    func resolveStreams(videoId: String) async throws -> YouTubeStreamSelection {
        let manifestURL = try await hlsPlaylistURL(videoId: videoId)
        let manifestText = try await fetchText(
            url: manifestURL,
            headers: ["User-Agent": iosUserAgent]
        )
        let parsed = Self.parseHLSMultivariant(manifestText)
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
        let body: [String: Any] = ["context": iosContext(languageCode: "en"), "videoId": videoId]
        let data = try await post(endpoint: "player", body: body, as: .ios)
        log("YouTube", "Player response for \(videoId): \(data.count) bytes")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let preview = String(data: data.prefix(512), encoding: .utf8) {
                log("YouTube", "Player response \(videoId) not JSON, preview: \(preview)")
            }
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
