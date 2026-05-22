import Foundation
import Hanami

extension NewYouTubeClient {

    /// Repackages the adaptive (DASH) formats into a locally servable HLS
    /// stream: a master playlist, byte-range media playlists for the video and
    /// every audio track, and WebVTT subtitle renditions from the caption
    /// tracks. Every dub is exposed as a selectable audio rendition.
    func buildLocalHLSStream(
        from entries: [[String: Any]],
        captionTracks: [[String: Any]],
        videoId: String
    ) async throws -> YouTubeLocalHLSStream {
        let formats = Self.parseAdaptiveFormats(entries)
        let audioFormats = Self.audioRenditionFormats(from: formats)
        guard
            let video = Self.selectVideoFormat(from: formats),
            let defaultAudio = Self.selectAudioFormat(from: formats),
            !audioFormats.isEmpty
        else {
            throw YouTubeBrowseError.missingData
        }
        Self.logAudioCandidates(from: entries, selected: defaultAudio, videoId: videoId)

        let audioRenditions = audioFormats.enumerated().map { index, format in
            YouTubeLocalAudioRendition(
                format: format,
                name: format.audioTrackDisplayName ?? "Audio",
                languageCode: format.audioLanguageCode,
                isDefault: format.itag == defaultAudio.itag
                    && format.audioTrackId == defaultAudio.audioTrackId,
                playlistName: "audio\(index).m3u8"
            )
        }
        let durationSeconds = Double(
            video.approximateDurationMilliseconds
                ?? defaultAudio.approximateDurationMilliseconds ?? 0
        ) / 1000.0
        let captionInfos = Self.parseCaptionTracks(captionTracks)

        async let subtitleTask = subtitleRenditions(from: captionInfos)
        let videoPlaylist = try await mediaPlaylist(for: video, mediaPath: "video.media")
        let audioPlaylists = await audioMediaPlaylists(for: audioRenditions)
        let subtitles = await subtitleTask

        var resources: [String: Data] = [
            "video.m3u8": Data(videoPlaylist.utf8)
        ]
        var mediaSources: [String: YouTubeLocalMediaSource] = [
            "video.media": Self.mediaSource(for: video)
        ]
        // A dub whose segment index fails to load is dropped rather than
        // failing the whole stream.
        var availableAudio: [YouTubeLocalAudioRendition] = []
        for (index, rendition) in audioRenditions.enumerated() {
            guard let playlist = audioPlaylists[index] else { continue }
            resources[rendition.playlistName] = Data(playlist.utf8)
            mediaSources[Self.mediaPath(for: rendition)] = Self.mediaSource(for: rendition.format)
            availableAudio.append(rendition)
        }
        guard !availableAudio.isEmpty else { throw YouTubeBrowseError.missingData }
        for subtitle in subtitles {
            resources[subtitle.vttName] = Data(subtitle.vtt.utf8)
            resources[subtitle.playlistName] = Data(
                Self.renderSubtitlePlaylist(
                    vttName: subtitle.vttName, durationSeconds: durationSeconds
                ).utf8
            )
        }
        resources["master.m3u8"] = Data(
            Self.renderMasterPlaylist(
                video: video, audioRenditions: availableAudio, subtitleRenditions: subtitles
            ).utf8
        )

        // swiftlint:disable:next line_length
        log("YouTube", "Built local HLS for \(videoId) video itag=\(video.itag) (\(video.width ?? 0)x\(video.height ?? 0)) audioTracks=\(availableAudio.count) subtitles=\(subtitles.count)")
        return YouTubeLocalHLSStream(
            resources: resources,
            mediaSources: mediaSources,
            resolution: Self.resolution(for: video),
            userAgent: iosUserAgent
        )
    }

    private static func mediaPath(for rendition: YouTubeLocalAudioRendition) -> String {
        rendition.playlistName.replacingOccurrences(of: ".m3u8", with: ".media")
    }

    private static func mediaSource(for format: YouTubeAdaptiveFormat) -> YouTubeLocalMediaSource {
        let baseMimeType = format.mimeType.split(separator: ";").first.map(String.init)
            ?? format.mimeType
        return YouTubeLocalMediaSource(
            url: format.url,
            contentLength: format.contentLength ?? 0,
            mimeType: baseMimeType
        )
    }

    private func audioMediaPlaylists(
        for renditions: [YouTubeLocalAudioRendition]
    ) async -> [Int: String] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, rendition) in renditions.enumerated() {
                let format = rendition.format
                let mediaPath = Self.mediaPath(for: rendition)
                group.addTask {
                    (index, try? await self.mediaPlaylist(for: format, mediaPath: mediaPath))
                }
            }
            var playlists: [Int: String] = [:]
            for await (index, playlist) in group {
                if let playlist { playlists[index] = playlist }
            }
            return playlists
        }
    }

    nonisolated private func mediaPlaylist(
        for format: YouTubeAdaptiveFormat,
        mediaPath: String
    ) async throws -> String {
        Self.renderMediaPlaylist(
            format: format, mediaPath: mediaPath, segments: try await segments(for: format)
        )
    }

    private static func logAudioCandidates(
        from entries: [[String: Any]],
        selected: YouTubeAdaptiveFormat,
        videoId: String
    ) {
        for entry in entries {
            guard
                let mimeType = entry["mimeType"] as? String,
                mimeType.hasPrefix("audio/")
            else { continue }
            let itag = entry["itag"] as? Int ?? -1
            let xtags = entry["xtags"] as? String ?? "(nil)"
            let track = (entry["audioTrack"] as? [String: Any]).map {
                String(describing: $0)
            } ?? "(nil)"
            // swiftlint:disable:next line_length
            log("YouTube", "Audio candidate \(videoId) itag=\(itag) xtags=\(xtags) audioTrack=\(track)")
        }
        // swiftlint:disable:next line_length
        log("YouTube", "Selected audio \(videoId) itag=\(selected.itag) original=\(selected.isOriginalAudioTrack) name=\(selected.audioTrackDisplayName ?? "(nil)")")
    }

    nonisolated private func segments(
        for format: YouTubeAdaptiveFormat
    ) async throws -> [YouTubeHLSSegment] {
        guard
            let indexRange = format.indexRange,
            let url = URL(string: format.url)
        else {
            return Self.singleSegment(for: format)
        }
        let indexData = try await fetchRange(
            url: url, start: indexRange.start, end: indexRange.end
        )
        guard
            let parsed = Self.parseSidx(indexData, indexEndOffset: indexRange.end),
            !parsed.isEmpty
        else {
            return Self.singleSegment(for: format)
        }
        return parsed
    }

    nonisolated private func fetchRange(url: URL, start: Int, end: Int) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YouTubeBrowseError.unexpectedResponse(status: http.statusCode)
        }
        return data
    }

    /// Fallback when no segment index is available: serve the whole media file
    /// after the init segment as a single HLS segment.
    nonisolated private static func singleSegment(
        for format: YouTubeAdaptiveFormat
    ) -> [YouTubeHLSSegment] {
        guard let contentLength = format.contentLength else { return [] }
        let mediaStart = (format.indexRange?.end).map { $0 + 1 }
            ?? format.initRange.map { $0.end + 1 }
            ?? 0
        let length = contentLength - mediaStart
        guard length > 0 else { return [] }
        let seconds = Double(format.approximateDurationMilliseconds ?? 0) / 1000.0
        return [
            YouTubeHLSSegment(
                offset: mediaStart,
                length: length,
                duration: seconds > 0 ? seconds : 1
            )
        ]
    }

    private static func renderMasterPlaylist(
        video: YouTubeAdaptiveFormat,
        audioRenditions: [YouTubeLocalAudioRendition],
        subtitleRenditions: [YouTubeLocalSubtitleRendition]
    ) -> String {
        let defaultAudio = audioRenditions.first(where: \.isDefault) ?? audioRenditions[0]
        let videoCodecs = video.codecs ?? "avc1.4d401f"
        let audioCodecs = defaultAudio.format.codecs ?? "mp4a.40.2"
        var lines = ["#EXTM3U", "#EXT-X-VERSION:7", "#EXT-X-INDEPENDENT-SEGMENTS"]

        // Only the original/default track is auto-selectable, so AVPlayer does
        // not switch to a dub that matches the device language. Dubs stay in the
        // group and remain selectable from the menu.
        for rendition in audioRenditions {
            var attributes = "TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"\(escapeAttribute(rendition.name))\""
            if let languageCode = rendition.languageCode {
                attributes += ",LANGUAGE=\"\(languageCode)\""
            }
            let flag = rendition.playlistName == defaultAudio.playlistName ? "YES" : "NO"
            attributes += ",DEFAULT=\(flag),AUTOSELECT=\(flag),URI=\"\(rendition.playlistName)\""
            lines.append("#EXT-X-MEDIA:\(attributes)")
        }
        for rendition in subtitleRenditions {
            // swiftlint:disable:next line_length
            lines.append("#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID=\"subs\",NAME=\"\(escapeAttribute(rendition.name))\",LANGUAGE=\"\(rendition.languageCode)\",AUTOSELECT=NO,DEFAULT=NO,URI=\"\(rendition.playlistName)\"")
        }

        var streamInfo = "#EXT-X-STREAM-INF:BANDWIDTH=\(video.bitrate + defaultAudio.format.bitrate)," +
            "CODECS=\"\(videoCodecs),\(audioCodecs)\",AUDIO=\"audio\""
        if !subtitleRenditions.isEmpty {
            streamInfo += ",SUBTITLES=\"subs\""
        }
        if let resolution = resolution(for: video) {
            streamInfo += ",RESOLUTION=\(resolution)"
        }
        lines.append(streamInfo)
        lines.append("video.m3u8")
        return lines.joined(separator: "\n") + "\n"
    }

    /// HLS attribute quoted-strings cannot contain double quotes or line breaks.
    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func renderSubtitlePlaylist(vttName: String, durationSeconds: Double) -> String {
        let duration = durationSeconds > 0 ? durationSeconds : 1
        return [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-TARGETDURATION:\(max(1, Int(duration.rounded(.up))))",
            "#EXT-X-MEDIA-SEQUENCE:0",
            String(format: "#EXTINF:%.5f,", duration),
            vttName,
            "#EXT-X-ENDLIST"
        ].joined(separator: "\n") + "\n"
    }

    nonisolated private static func renderMediaPlaylist(
        format: YouTubeAdaptiveFormat,
        mediaPath: String,
        segments: [YouTubeHLSSegment]
    ) -> String {
        let targetDuration = max(1, Int((segments.map(\.duration).max() ?? 1).rounded(.up)))
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-TARGETDURATION:\(targetDuration)",
            "#EXT-X-MEDIA-SEQUENCE:0"
        ]
        if let initRange = format.initRange {
            lines.append(
                "#EXT-X-MAP:URI=\"\(mediaPath)\",BYTERANGE=\"\(initRange.length)@\(initRange.start)\""
            )
        }
        for segment in segments {
            lines.append(String(format: "#EXTINF:%.5f,", segment.duration))
            lines.append("#EXT-X-BYTERANGE:\(segment.length)@\(segment.offset)")
            lines.append(mediaPath)
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func resolution(for format: YouTubeAdaptiveFormat) -> String? {
        guard let width = format.width, let height = format.height else { return nil }
        return "\(width)x\(height)"
    }
}
