import Foundation

extension YouTubePlaylistProvider {

    // MARK: - JSON Extraction

    /// Extracts the ytInitialData JSON blob. Handles both desktop raw-object and
    /// mobile hex-escaped single-quoted formats.
    static func extractYTInitialData(from html: String) -> [String: Any]? {
        let marker = "var ytInitialData = "
        guard let markerRange = html.range(of: marker) else {
            print("[YouTubePlaylist] Could not find ytInitialData in page HTML.")
            return nil
        }

        let startIndex = markerRange.upperBound
        guard startIndex < html.endIndex else { return nil }

        let firstChar = html[startIndex]

        let jsonString: String
        if firstChar == "'" {
            guard let parsed = extractSingleQuotedValue(from: html, startIndex: startIndex) else {
                print("[YouTubePlaylist] Failed to extract single-quoted ytInitialData.")
                return nil
            }
            jsonString = parsed
        } else if firstChar == "{" {
            jsonString = extractBraceBalancedJSON(from: html, startIndex: startIndex)
        } else {
            print("[YouTubePlaylist] Unexpected ytInitialData format.")
            return nil
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[YouTubePlaylist] Failed to parse ytInitialData JSON.")
            return nil
        }
        return json
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private static func extractSingleQuotedValue(
        from html: String, startIndex: String.Index
    ) -> String? {
        let contentStart = html.index(after: startIndex)
        guard contentStart < html.endIndex else { return nil }

        // `';` avoids matching escaped quotes inside the payload.
        guard let endRange = html.range(of: "';", range: contentStart..<html.endIndex) else {
            return nil
        }

        let escaped = String(html[contentStart..<endRange.lowerBound])

        var result = ""
        var index = escaped.startIndex
        while index < escaped.endIndex {
            if escaped[index] == "\\" {
                let next = escaped.index(after: index)
                guard next < escaped.endIndex else {
                    result.append(escaped[index])
                    index = next
                    continue
                }
                switch escaped[next] {
                case "x":
                    let hexStart = escaped.index(after: next)
                    if let hexEnd = escaped.index(
                        hexStart, offsetBy: 2, limitedBy: escaped.endIndex
                    ),
                       let byte = UInt8(String(escaped[hexStart..<hexEnd]), radix: 16) {
                        result.append(Character(UnicodeScalar(byte)))
                        index = hexEnd
                    } else {
                        result.append(escaped[index])
                        index = next
                    }
                case "u":
                    let hexStart = escaped.index(after: next)
                    if let hexEnd = escaped.index(
                        hexStart, offsetBy: 4, limitedBy: escaped.endIndex
                    ),
                       let codePoint = UInt32(String(escaped[hexStart..<hexEnd]), radix: 16),
                       let scalar = Unicode.Scalar(codePoint) {
                        result.append(Character(scalar))
                        index = hexEnd
                    } else {
                        result.append(escaped[index])
                        index = next
                    }
                case "\\":
                    result.append("\\")
                    index = escaped.index(after: next)
                case "/":
                    result.append("/")
                    index = escaped.index(after: next)
                case "n":
                    result.append("\n")
                    index = escaped.index(after: next)
                case "r":
                    result.append("\r")
                    index = escaped.index(after: next)
                case "t":
                    result.append("\t")
                    index = escaped.index(after: next)
                case "'":
                    result.append("'")
                    index = escaped.index(after: next)
                default:
                    result.append(escaped[index])
                    index = next
                }
                continue
            }
            result.append(escaped[index])
            index = escaped.index(after: index)
        }
        return result
    }

    private static func extractBraceBalancedJSON(
        from html: String, startIndex: String.Index
    ) -> String {
        var depth = 0
        var endIndex = startIndex
        var started = false

        for indice in html[startIndex...].indices {
            // swiftlint:disable:next identifier_name
            let ch = html[indice]
            if ch == "{" {
                depth += 1
                started = true
            } else if ch == "}" {
                depth -= 1
            }
            if started && depth == 0 {
                endIndex = html.index(after: indice)
                break
            }
        }

        return String(html[startIndex..<endIndex])
    }

    // MARK: - Playlist Parsing

    /// Extracts the channel owner's avatar URL, upscaling the `=sN-` suffix to 176px.
    static func parseChannelAvatarURL(from ytData: [String: Any]) -> String? {
        var rawURL: String?

        if let header = ytData["header"] as? [String: Any],
           let url = findAvatarViewModelURL(in: header) {
            rawURL = url
        }

        if rawURL == nil, let sidebar = ytData["sidebar"] as? [String: Any],
           let url = findVideoOwnerThumbnailURL(in: sidebar) {
            rawURL = url
        }

        guard let url = rawURL else { return nil }
        return upscaleAvatarURL(url)
    }

    private static func findAvatarViewModelURL(in node: Any) -> String? {
        if let dict = node as? [String: Any] {
            if let avatar = dict["avatarViewModel"] as? [String: Any],
               let image = avatar["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]],
               !sources.isEmpty {
                let best = sources.max { lhs, rhs in
                    (lhs["width"] as? Int ?? 0) < (rhs["width"] as? Int ?? 0)
                }
                if let url = best?["url"] as? String { return url }
            }
            for (_, value) in dict {
                if let found = findAvatarViewModelURL(in: value) { return found }
            }
        } else if let array = node as? [Any] {
            for item in array {
                if let found = findAvatarViewModelURL(in: item) { return found }
            }
        }
        return nil
    }

    private static func findVideoOwnerThumbnailURL(in node: Any) -> String? {
        if let dict = node as? [String: Any] {
            if let owner = dict["videoOwnerRenderer"] as? [String: Any],
               let thumb = owner["thumbnail"] as? [String: Any],
               let thumbs = thumb["thumbnails"] as? [[String: Any]],
               let best = thumbs.last,
               let url = best["url"] as? String {
                return url
            }
            for (_, value) in dict {
                if let found = findVideoOwnerThumbnailURL(in: value) { return found }
            }
        } else if let array = node as? [Any] {
            for item in array {
                if let found = findVideoOwnerThumbnailURL(in: item) { return found }
            }
        }
        return nil
    }

    private static func upscaleAvatarURL(_ url: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "=s\\d+-") else { return url }
        let range = NSRange(url.startIndex..., in: url)
        return regex.stringByReplacingMatches(
            in: url, range: range, withTemplate: "=s176-"
        )
    }

    static func parsePlaylistTitle(from ytData: [String: Any]) -> String? {
        if let header = ytData["header"] as? [String: Any],
           let pageHeader = header["pageHeaderRenderer"] as? [String: Any],
           let pageTitle = pageHeader["pageTitle"] as? String {
            return pageTitle
        }

        if let metadata = ytData["metadata"] as? [String: Any],
           let playlistMeta = metadata["playlistMetadataRenderer"] as? [String: Any],
           let title = playlistMeta["title"] as? String {
            return title
        }

        if let microformat = ytData["microformat"] as? [String: Any],
           let mfData = microformat["microformatDataRenderer"] as? [String: Any],
           let rawTitle = mfData["title"] as? String {
            let suffix = " - YouTube"
            if rawTitle.hasSuffix(suffix) {
                return String(rawTitle.dropLast(suffix.count))
            }
            return rawTitle
        }

        return nil
    }

    static func parsePlaylistVideos(from ytData: [String: Any]) -> [ParsedPlaylistVideo] {
        guard let contents = ytData["contents"] as? [String: Any] else { return [] }

        let videoEntries: [[String: Any]]
        if let singleCol = contents["singleColumnBrowseResultsRenderer"] as? [String: Any] {
            videoEntries = extractVideoEntries(fromBrowseRenderer: singleCol) ?? []
        } else if let twoCol = contents["twoColumnBrowseResultsRenderer"] as? [String: Any] {
            videoEntries = extractVideoEntries(fromBrowseRenderer: twoCol) ?? []
        } else {
            print("[YouTubePlaylist] Could not find browse results renderer.")
            return []
        }

        var videos: [ParsedPlaylistVideo] = []

        for entry in videoEntries {
            guard let renderer = entry["playlistVideoRenderer"] as? [String: Any] else {
                continue
            }

            guard let videoId = renderer["videoId"] as? String else { continue }

            let title: String
            if let titleObj = renderer["title"] as? [String: Any],
               let runs = titleObj["runs"] as? [[String: Any]],
               let firstRun = runs.first,
               let text = firstRun["text"] as? String {
                title = text
            } else {
                title = "(Unknown Title)"
            }

            let thumbnailURL: String
            if let thumbObj = renderer["thumbnail"] as? [String: Any],
               let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
               let best = thumbs.last,
               let url = best["url"] as? String {
                thumbnailURL = url
            } else {
                thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
            }

            let relativeDate = parseRelativeDate(fromRenderer: renderer)

            videos.append(ParsedPlaylistVideo(
                videoId: videoId,
                title: title,
                thumbnailURL: thumbnailURL,
                publishedDate: relativeDate
            ))
        }

        return videos
    }

    /// Parses the "N units ago" string in `videoInfo.runs` into an approximate Date.
    /// Used as a fallback for videos not present in the playlist's Atom feed (which caps at ~15 entries).
    private static func parseRelativeDate(fromRenderer renderer: [String: Any]) -> Date? {
        guard let videoInfo = renderer["videoInfo"] as? [String: Any],
              let runs = videoInfo["runs"] as? [[String: Any]] else {
            return nil
        }
        for run in runs {
            guard let text = run["text"] as? String else { continue }
            if let date = relativeDate(fromText: text) {
                return date
            }
        }
        return nil
    }

    /// Parses the precise upload date from a YouTube watch page's embedded JSON.
    /// Looks for `"publishDate":"YYYY-MM-DD"` from `playerMicroformatRenderer`.
    static func parseVideoPublishDate(fromHTML html: String) -> Date? {
        let pattern = #""publishDate"\s*:\s*"(\d{4}-\d{2}-\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges >= 2,
              let dateRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: String(html[dateRange]))
    }

    static func relativeDate(fromText text: String) -> Date? {
        let pattern = #"(\d+)\s+(second|minute|hour|day|week|month|year)s?\s+ago"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 3,
              let amountRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let amount = Int(text[amountRange]) else {
            return nil
        }
        let unit = text[unitRange].lowercased()
        let component: Calendar.Component
        switch unit {
        case "second": component = .second
        case "minute": component = .minute
        case "hour": component = .hour
        case "day": component = .day
        case "week": component = .weekOfYear
        case "month": component = .month
        case "year": component = .year
        default: return nil
        }
        return Calendar.current.date(byAdding: component, value: -amount, to: Date())
    }

    private static func extractVideoEntries(
        fromBrowseRenderer renderer: [String: Any]
    ) -> [[String: Any]]? {
        guard let tabs = renderer["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]],
              let firstSection = sectionContents.first,
              let itemSection = firstSection["itemSectionRenderer"] as? [String: Any],
              let itemContents = itemSection["contents"] as? [[String: Any]],
              let firstItem = itemContents.first,
              let playlistVideoList = firstItem["playlistVideoListRenderer"] as? [String: Any],
              let videoEntries = playlistVideoList["contents"] as? [[String: Any]] else {
            return nil
        }
        return videoEntries
    }
}
