import Foundation

public extension FeedManager {

    /// Classifies a non-XML response body so parse-failure logs show why
    /// (e.g. YouTube returning an HTML 500 page instead of an Atom feed).
    nonisolated static func bodyContentHint(data: Data) -> String {
        if data.isEmpty { return "empty" }
        let prefix = data.prefix(512)
        guard let snippet = String(data: prefix, encoding: .utf8)
                ?? String(data: prefix, encoding: .isoLatin1) else {
            return "binary"
        }
        let trimmed = snippet
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if trimmed.hasPrefix("<!doctype html") || trimmed.hasPrefix("<html") {
            return "html"
        }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return "json"
        }
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<rss")
            || trimmed.hasPrefix("<feed") || trimmed.hasPrefix("<atom") {
            return "xml-malformed"
        }
        return "other:" + String(trimmed.prefix(60))
    }
}
