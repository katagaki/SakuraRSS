import Foundation

public nonisolated enum BookmarkExporter {

    /// `unsortedFolderName` labels bookmarks that aren't in a folder; the app
    /// passes a localized string since Hanami carries no string table.
    public static func export(
        _ items: [ExportedBookmark],
        as format: BookmarkExportFormat,
        unsortedFolderName: String = "Unsorted"
    ) -> String {
        switch format {
        case .json: json(items)
        case .csv: csv(items)
        case .html: netscapeHTML(items, unsortedFolderName: unsortedFolderName)
        case .markdown: markdown(items, unsortedFolderName: unsortedFolderName)
        }
    }

    private static func timestamp(_ date: Date?) -> String {
        date.map { $0.formatted(.iso8601) } ?? ""
    }

    private static func json(_ items: [ExportedBookmark]) -> String {
        let payload = items.map { item in
            [
                "title": item.title,
                "originalTitle": item.originalTitle,
                "url": item.url,
                "folder": item.folder ?? NSNull(),
                "tags": item.tags,
                "savedDate": timestamp(item.savedDate),
                "isRead": item.isRead
            ] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { return "[]" }
        return String(bytes: data, encoding: .utf8) ?? "[]"
    }

    private static func csv(_ items: [ExportedBookmark]) -> String {
        let header = "title,url,folder,tags,saved_date,is_read"
        let rows = items.map { item in
            [
                quoted(item.title),
                quoted(item.url),
                quoted(item.folder ?? ""),
                quoted(item.tags.joined(separator: " ")),
                quoted(timestamp(item.savedDate)),
                item.isRead ? "true" : "false"
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Netscape bookmark format, which Safari and most read-later apps import.
    private static func netscapeHTML(_ items: [ExportedBookmark], unsortedFolderName: String) -> String {
        var lines = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<TITLE>Sakura Bookmarks</TITLE>",
            "<H1>Sakura Bookmarks</H1>",
            "<DL><p>"
        ]
        for group in grouped(items, unsortedFolderName: unsortedFolderName) {
            lines.append("    <DT><H3>\(escaped(group.name))</H3>")
            lines.append("    <DL><p>")
            for item in group.items {
                let seconds = Int(item.savedDate?.timeIntervalSince1970 ?? 0)
                let tags = item.tags.joined(separator: ",")
                // swiftlint:disable:next line_length
                lines.append("        <DT><A HREF=\"\(escaped(item.url))\" ADD_DATE=\"\(seconds)\" TAGS=\"\(escaped(tags))\">\(escaped(item.title))</A>")
            }
            lines.append("    </DL><p>")
        }
        lines.append("</DL><p>")
        return lines.joined(separator: "\n")
    }

    private static func markdown(_ items: [ExportedBookmark], unsortedFolderName: String) -> String {
        var lines = ["# Sakura Bookmarks", ""]
        for group in grouped(items, unsortedFolderName: unsortedFolderName) {
            lines.append("## \(group.name)")
            lines.append("")
            for item in group.items {
                let tags = item.tags
                    .map { "#\($0.replacingOccurrences(of: " ", with: ""))" }
                    .joined(separator: " ")
                lines.append("- [\(item.title)](\(item.url))\(tags.isEmpty ? "" : " — \(tags)")")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private static func grouped(
        _ items: [ExportedBookmark],
        unsortedFolderName: String
    ) -> [(name: String, items: [ExportedBookmark])] {
        Dictionary(grouping: items) { $0.folder ?? unsortedFolderName }
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .map { (name: $0.key, items: $0.value) }
    }

    private static func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
