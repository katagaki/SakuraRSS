import Foundation

extension YouTubePlaylistScraper {

    // MARK: - JSON Extraction

    /// Extracts the ytInitialData JSON blob from YouTube's HTML.
    ///
    /// YouTube serves two formats depending on the user agent:
    /// - Desktop: `var ytInitialData = { ... };`  (raw JSON object)
    /// - Mobile:  `var ytInitialData = '\x7b...';` (hex-escaped string in single quotes)
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
            // Mobile format: hex-escaped JSON in single quotes
            guard let parsed = extractSingleQuotedValue(from: html, startIndex: startIndex) else {
                print("[YouTubePlaylist] Failed to extract single-quoted ytInitialData.")
                return nil
            }
            jsonString = parsed
        } else if firstChar == "{" {
            // Desktop format: raw JSON object
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

    /// Extracts a single-quoted, hex-escaped string value starting at the opening quote.
    private static func extractSingleQuotedValue(
        from html: String, startIndex: String.Index
    ) -> String? {
        // Skip the opening single quote
        let contentStart = html.index(after: startIndex)
        guard contentStart < html.endIndex else { return nil }

        // Find the closing single quote followed by ; (to avoid matching escaped quotes)
        guard let endRange = html.range(of: "';", range: contentStart..<html.endIndex) else {
            return nil
        }

        let escaped = String(html[contentStart..<endRange.lowerBound])

        // Decode JavaScript string escapes: \xHH, \uHHHH, \\, \/, \n, \r, \t, \'
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
                    // \xHH — two-digit hex
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
                    // \uHHHH — four-digit unicode
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

    /// Extracts a brace-balanced JSON object from HTML starting at the opening brace.
    private static func extractBraceBalancedJSON(
        from html: String, startIndex: String.Index
    ) -> String {
        var depth = 0
        var endIndex = startIndex
        var started = false

        for indice in html[startIndex...].indices {
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

    /// Extracts the playlist title from ytInitialData.
    static func parsePlaylistTitle(from ytData: [String: Any]) -> String? {
        // Try header > pageHeaderRenderer > pageTitle (mobile)
        if let header = ytData["header"] as? [String: Any],
           let pageHeader = header["pageHeaderRenderer"] as? [String: Any],
           let pageTitle = pageHeader["pageTitle"] as? String {
            return pageTitle
        }

        // Try metadata > playlistMetadataRenderer > title (desktop)
        if let metadata = ytData["metadata"] as? [String: Any],
           let playlistMeta = metadata["playlistMetadataRenderer"] as? [String: Any],
           let title = playlistMeta["title"] as? String {
            return title
        }

        // Try microformat > microformatDataRenderer > title (strip " - YouTube" suffix)
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

    /// Walks the ytInitialData structure to extract playlist video entries.
    /// Supports both mobile (singleColumnBrowseResultsRenderer) and
    /// desktop (twoColumnBrowseResultsRenderer) layouts.
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

            // Title: title.runs[0].text
            let title: String
            if let titleObj = renderer["title"] as? [String: Any],
               let runs = titleObj["runs"] as? [[String: Any]],
               let firstRun = runs.first,
               let text = firstRun["text"] as? String {
                title = text
            } else {
                title = "(Unknown Title)"
            }

            // Thumbnail: pick the highest-resolution thumbnail available
            let thumbnailURL: String
            if let thumbObj = renderer["thumbnail"] as? [String: Any],
               let thumbs = thumbObj["thumbnails"] as? [[String: Any]],
               let best = thumbs.last,
               let url = best["url"] as? String {
                thumbnailURL = url
            } else {
                thumbnailURL = "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg"
            }

            videos.append(ParsedPlaylistVideo(
                videoId: videoId, title: title, thumbnailURL: thumbnailURL
            ))
        }

        return videos
    }

    /// Navigates the tabs > sectionList > itemSection > playlistVideoList hierarchy
    /// shared by both single- and two-column layouts.
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
