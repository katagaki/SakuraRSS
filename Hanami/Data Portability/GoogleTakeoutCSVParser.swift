import Foundation

public nonisolated enum GoogleTakeoutCSVParser {

    /// Parses a Google Takeout `subscriptions.csv` export
    /// (columns: Channel ID, Channel URL, Channel Name).
    public static func parseSubscriptions(data: Data) -> [OPMLFeed] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var feeds: [OPMLFeed] = []
        for (rowIndex, columns) in parseRows(from: text).enumerated() {
            guard columns.count >= 2 else { continue }
            if rowIndex == 0 && isHeaderRow(columns) { continue }

            let channelURL = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let channelName = columns.count >= 3
                ? columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            guard let channelID = channelID(fromChannelURL: channelURL)
                ?? normalizedChannelID(columns[0]) else {
                continue
            }

            feeds.append(OPMLFeed(
                title: channelName.isEmpty ? channelID : channelName,
                xmlURL: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)",
                htmlURL: channelURL.isEmpty
                    ? "https://www.youtube.com/channel/\(channelID)"
                    : channelURL,
                description: "",
                category: nil
            ))
        }
        return feeds
    }

    private static func isHeaderRow(_ columns: [String]) -> Bool {
        columns[0].lowercased().contains("channel")
    }

    private static func channelID(fromChannelURL channelURL: String) -> String? {
        guard let url = URL(string: channelURL),
              let host = url.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com"),
              url.path.hasPrefix("/channel/") else {
            return nil
        }
        let remainder = url.path.dropFirst("/channel/".count)
        let channelID = String(remainder.split(separator: "/").first ?? "")
        return channelID.hasPrefix("UC") ? channelID : nil
    }

    private static func normalizedChannelID(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("UC") ? trimmed : nil
    }

    static func parseRows(from text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var characterIndex = text.startIndex

        func endField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func endRow() {
            endField()
            if !currentRow.allSatisfy(\.isEmpty) {
                rows.append(currentRow)
            }
            currentRow = []
        }

        while characterIndex < text.endIndex {
            let character = text[characterIndex]
            if isInsideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: characterIndex)
                    if nextIndex < text.endIndex && text[nextIndex] == "\"" {
                        currentField.append("\"")
                        characterIndex = nextIndex
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isInsideQuotes = true
                case ",":
                    endField()
                case "\r":
                    break
                case "\n":
                    endRow()
                default:
                    currentField.append(character)
                }
            }
            characterIndex = text.index(after: characterIndex)
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            endRow()
        }
        return rows
    }
}
