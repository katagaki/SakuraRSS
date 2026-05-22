import Foundation
import Hanami

extension NewYouTubeClient {

    /// Repackages the adaptive (DASH) formats into a locally servable HLS
    /// stream: a master playlist plus byte-range media playlists for the chosen
    /// video and audio tracks.
    func buildLocalHLSStream(
        from entries: [[String: Any]],
        videoId: String
    ) async throws -> YouTubeLocalHLSStream {
        let formats = Self.parseAdaptiveFormats(entries)
        guard
            let video = Self.selectVideoFormat(from: formats),
            let audio = Self.selectAudioFormat(from: formats)
        else {
            throw YouTubeBrowseError.missingData
        }
        Self.logAudioCandidates(from: formats, selected: audio, videoId: videoId)
        async let videoSegments = segments(for: video)
        async let audioSegments = segments(for: audio)
        let videoPlaylist = Self.renderMediaPlaylist(
            format: video, segments: try await videoSegments
        )
        let audioPlaylist = Self.renderMediaPlaylist(
            format: audio, segments: try await audioSegments
        )
        // swiftlint:disable:next line_length
        log("YouTube", "Built local HLS for \(videoId) video itag=\(video.itag) (\(video.width ?? 0)x\(video.height ?? 0)) audio itag=\(audio.itag)")
        return YouTubeLocalHLSStream(
            masterPlaylist: Self.renderMasterPlaylist(video: video, audio: audio),
            videoPlaylist: videoPlaylist,
            audioPlaylist: audioPlaylist,
            resolution: Self.resolution(for: video)
        )
    }

    private static func logAudioCandidates(
        from formats: [YouTubeAdaptiveFormat],
        selected: YouTubeAdaptiveFormat,
        videoId: String
    ) {
        let audioFormats = formats.filter { $0.isAudio && $0.isMP4 }
        for format in audioFormats {
            // swiftlint:disable:next line_length
            log("YouTube", "Audio candidate \(videoId) itag=\(format.itag) default=\(String(describing: format.isDefaultAudioTrack)) original=\(format.isOriginalAudioTrack) name=\(format.audioTrackDisplayName ?? "(nil)")")
        }
        // swiftlint:disable:next line_length
        log("YouTube", "Selected audio \(videoId) itag=\(selected.itag) original=\(selected.isOriginalAudioTrack) name=\(selected.audioTrackDisplayName ?? "(nil)")")
    }

    private func segments(for format: YouTubeAdaptiveFormat) async throws -> [YouTubeHLSSegment] {
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

    private func fetchRange(url: URL, start: Int, end: Int) async throws -> Data {
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
    private static func singleSegment(for format: YouTubeAdaptiveFormat) -> [YouTubeHLSSegment] {
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
        audio: YouTubeAdaptiveFormat
    ) -> String {
        let videoCodecs = video.codecs ?? "avc1.4d401f"
        let audioCodecs = audio.codecs ?? "mp4a.40.2"
        var streamInfo = "#EXT-X-STREAM-INF:BANDWIDTH=\(video.bitrate + audio.bitrate)," +
            "CODECS=\"\(videoCodecs),\(audioCodecs)\",AUDIO=\"audio\""
        if let resolution = resolution(for: video) {
            streamInfo += ",RESOLUTION=\(resolution)"
        }
        return [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-INDEPENDENT-SEGMENTS",
            // swiftlint:disable:next line_length
            "#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID=\"audio\",NAME=\"Audio\",DEFAULT=YES,AUTOSELECT=YES,URI=\"audio.m3u8\"",
            streamInfo,
            "video.m3u8"
        ].joined(separator: "\n") + "\n"
    }

    private static func renderMediaPlaylist(
        format: YouTubeAdaptiveFormat,
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
                "#EXT-X-MAP:URI=\"\(format.url)\",BYTERANGE=\"\(initRange.length)@\(initRange.start)\""
            )
        }
        for segment in segments {
            lines.append(String(format: "#EXTINF:%.5f,", segment.duration))
            lines.append("#EXT-X-BYTERANGE:\(segment.length)@\(segment.offset)")
            lines.append(format.url)
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func resolution(for format: YouTubeAdaptiveFormat) -> String? {
        guard let width = format.width, let height = format.height else { return nil }
        return "\(width)x\(height)"
    }
}
