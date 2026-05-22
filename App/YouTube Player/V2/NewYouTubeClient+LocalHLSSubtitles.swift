import Foundation
import Hanami

extension NewYouTubeClient {

    nonisolated struct CaptionTrackInfo: Sendable {
        let index: Int
        let url: URL
        let name: String
        let languageCode: String
    }

    static func captionTracks(from manifest: [String: Any]) -> [[String: Any]] {
        guard
            let captions = manifest["captions"] as? [String: Any],
            let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
            let tracks = renderer["captionTracks"] as? [[String: Any]]
        else { return [] }
        return tracks
    }

    static func parseCaptionTracks(_ tracks: [[String: Any]]) -> [CaptionTrackInfo] {
        var infos: [CaptionTrackInfo] = []
        for track in tracks {
            guard
                let baseUrl = track["baseUrl"] as? String,
                let url = URL(string: baseUrl.contains("fmt=") ? baseUrl : baseUrl + "&fmt=vtt")
            else { continue }
            infos.append(CaptionTrackInfo(
                index: infos.count,
                url: url,
                name: captionName(track),
                languageCode: track["languageCode"] as? String ?? "und"
            ))
        }
        return infos
    }

    func subtitleRenditions(
        from tracks: [CaptionTrackInfo]
    ) async -> [YouTubeLocalSubtitleRendition] {
        guard !tracks.isEmpty else { return [] }
        return await withTaskGroup(of: (Int, YouTubeLocalSubtitleRendition?).self) { group in
            for track in tracks {
                group.addTask { (track.index, await self.subtitleRendition(from: track)) }
            }
            var collected = [YouTubeLocalSubtitleRendition?](repeating: nil, count: tracks.count)
            for await (index, rendition) in group where index < collected.count {
                collected[index] = rendition
            }
            return collected.compactMap { $0 }
        }
    }

    private func subtitleRendition(
        from track: CaptionTrackInfo
    ) async -> YouTubeLocalSubtitleRendition? {
        guard let vtt = await fetchSubtitleText(url: track.url), !vtt.isEmpty else { return nil }
        return YouTubeLocalSubtitleRendition(
            name: track.name,
            languageCode: track.languageCode,
            vttName: "sub\(track.index).vtt",
            playlistName: "sub\(track.index).m3u8",
            vtt: vtt
        )
    }

    private func fetchSubtitleText(url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue(iosUserAgent, forHTTPHeaderField: "User-Agent")
        guard
            let (data, response) = try? await session.data(for: request),
            let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func captionName(_ track: [String: Any]) -> String {
        if let name = track["name"] as? [String: Any] {
            if let simpleText = name["simpleText"] as? String { return simpleText }
            if let runs = name["runs"] as? [[String: Any]] {
                let joined = runs.compactMap { $0["text"] as? String }.joined()
                if !joined.isEmpty { return joined }
            }
        }
        return track["languageCode"] as? String ?? "Subtitles"
    }
}
