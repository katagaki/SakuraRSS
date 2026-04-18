import Foundation

extension FaviconCache {

    /// Extracts the href attribute from a link tag with the given rel value.
    nonisolated func extractLinkHref(from html: String, rel: String) -> String? {
        let patterns = [
            "<link[^>]+rel=\"\(rel)\"[^>]+href=\"([^\"]+)\"",
            "<link[^>]+href=\"([^\"]+)\"[^>]+rel=\"\(rel)\""
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }

    /// Extracts the content attribute from a meta tag with the given property.
    nonisolated func extractMetaContent(from html: String, property: String) -> String? {
        let patterns = [
            "<meta[^>]+property=\"\(property)\"[^>]+content=\"([^\"]+)\"",
            "<meta[^>]+content=\"([^\"]+)\"[^>]+property=\"\(property)\""
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        return nil
    }
}
