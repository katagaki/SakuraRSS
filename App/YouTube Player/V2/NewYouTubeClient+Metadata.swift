import Foundation
import Hanami

extension NewYouTubeClient {
    func fetchVideoMetadata(videoId: String) async throws -> YouTubeVideoMetadata {
        let playerBody: [String: Any] = ["context": webContext(), "videoId": videoId]
        async let playerTask = post(endpoint: "player", body: playerBody)
        let nextBody: [String: Any] = ["context": webContext(), "videoId": videoId]
        async let nextTask = post(endpoint: "next", body: nextBody)
        let playerData = try await playerTask
        let nextData = try? await nextTask

        guard let root = try JSONSerialization.jsonObject(with: playerData) as? [String: Any] else {
            throw YouTubeBrowseError.decodingFailed
        }
        let nextRoot: [String: Any] = {
            guard let nextData,
                  let parsed = (try? JSONSerialization.jsonObject(with: nextData))
                    as? [String: Any]
            else { return [:] }
            return parsed
        }()

        let videoDetails = root["videoDetails"] as? [String: Any] ?? [:]
        let microformat = (root["microformat"] as? [String: Any])?["playerMicroformatRenderer"]
            as? [String: Any] ?? [:]

        let title = (videoDetails["title"] as? String)
            ?? Self.simpleText(microformat["title"]) ?? ""
        let uploader = (videoDetails["author"] as? String)
            ?? (microformat["ownerChannelName"] as? String) ?? ""
        let description = (videoDetails["shortDescription"] as? String)
            ?? Self.simpleText(microformat["description"]) ?? ""
        let publishDate = (microformat["publishDate"] as? String)
            ?? (microformat["uploadDate"] as? String)
        let chapters = Self.extractChapters(playerResponse: root, nextResponse: nextRoot)

        return YouTubeVideoMetadata(
            videoId: videoId,
            title: title,
            uploader: uploader,
            description: description,
            publishDateString: publishDate,
            chapters: chapters
        )
    }

    private static func simpleText(_ object: Any?) -> String? {
        guard let dictionary = object as? [String: Any] else { return nil }
        if let simple = dictionary["simpleText"] as? String { return simple }
        if let runs = dictionary["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return nil
    }

    private static func extractChapters(
        playerResponse: [String: Any],
        nextResponse: [String: Any]
    ) -> [YouTubeChapter] {
        let fromOverlays = chaptersFromPlayerOverlays(playerResponse)
        if !fromOverlays.isEmpty { return fromOverlays }
        let fromNextPanels = chaptersFromEngagementPanels(nextResponse)
        if !fromNextPanels.isEmpty { return fromNextPanels }
        return chaptersFromEngagementPanels(playerResponse)
    }

    private static func chaptersFromPlayerOverlays(
        _ playerResponse: [String: Any]
    ) -> [YouTubeChapter] {
        guard
            let overlays = playerResponse["playerOverlays"] as? [String: Any],
            let overlayRenderer = overlays["playerOverlayRenderer"] as? [String: Any],
            let outer = overlayRenderer["decoratedPlayerBarRenderer"] as? [String: Any],
            let inner = outer["decoratedPlayerBarRenderer"] as? [String: Any],
            let playerBar = inner["playerBar"] as? [String: Any],
            let markers = playerBar["multiMarkersPlayerBarRenderer"] as? [String: Any],
            let markersMap = markers["markersMap"] as? [[String: Any]]
        else { return [] }
        let entry = markersMap.first { entry in
            guard let key = entry["key"] as? String else { return false }
            return key == "DESCRIPTION_CHAPTERS" || key == "AUTO_CHAPTERS"
        }
        guard
            let value = entry?["value"] as? [String: Any],
            let chapters = value["chapters"] as? [[String: Any]]
        else { return [] }
        return chapters.enumerated().compactMap { index, raw in
            guard let renderer = raw["chapterRenderer"] as? [String: Any] else { return nil }
            let title = simpleText(renderer["title"]) ?? ""
            guard !title.isEmpty else { return nil }
            let millis = (renderer["timeRangeStartMillis"] as? Double)
                ?? Double(renderer["timeRangeStartMillis"] as? Int ?? 0)
            return YouTubeChapter(id: index, title: title, startTime: millis / 1000.0)
        }
    }

    private static func chaptersFromEngagementPanels(
        _ playerResponse: [String: Any]
    ) -> [YouTubeChapter] {
        guard let panels = playerResponse["engagementPanels"] as? [[String: Any]] else { return [] }
        for panel in panels {
            guard let renderer = panel["engagementPanelSectionListRenderer"] as? [String: Any]
            else { continue }
            let target = (renderer["targetId"] as? String)
                ?? (renderer["panelIdentifier"] as? String) ?? ""
            guard target.contains("macro-markers") || target.contains("chapters") else { continue }
            guard
                let content = renderer["content"] as? [String: Any],
                let list = content["macroMarkersListRenderer"] as? [String: Any],
                let items = list["contents"] as? [[String: Any]]
            else { continue }
            let parsed = items.enumerated().compactMap { index, raw in
                macroMarkerChapter(at: index, from: raw)
            }
            if !parsed.isEmpty { return parsed }
        }
        return []
    }

    private static func macroMarkerChapter(
        at index: Int, from raw: [String: Any]
    ) -> YouTubeChapter? {
        guard let item = raw["macroMarkersListItemRenderer"] as? [String: Any] else { return nil }
        let title = simpleText(item["title"]) ?? ""
        guard !title.isEmpty else { return nil }
        let startSeconds = macroMarkerStartSeconds(from: item)
        return YouTubeChapter(id: index, title: title, startTime: startSeconds)
    }

    private static func macroMarkerStartSeconds(from item: [String: Any]) -> TimeInterval {
        if let tap = item["onTap"] as? [String: Any],
           let endpoint = tap["watchEndpoint"] as? [String: Any] {
            if let seconds = endpoint["startTimeSeconds"] as? Double { return seconds }
            if let seconds = endpoint["startTimeSeconds"] as? Int { return TimeInterval(seconds) }
        }
        return parseTimestamp(simpleText(item["timeDescription"]) ?? "")
    }

    private static func parseTimestamp(_ text: String) -> TimeInterval {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        case 2: return TimeInterval(parts[0] * 60 + parts[1])
        case 1: return TimeInterval(parts[0])
        default: return 0
        }
    }
}
