import Foundation

extension ArticleExtractor {

    /// Resolves a potentially relative URL string against a base URL.
    /// Returns the resolved absolute URL string, or nil if it can't be resolved.
    /// Tracking parameters (utm_*, fbclid, gclid, ...) are stripped so images
    /// that differ only in tracking tags share a cache entry.
    static func resolveURL(_ src: String, against baseURL: URL?) -> String? {
        let decoded = htmlEntityDecodedURL(src)
        // Already absolute
        if decoded.hasPrefix("http://") || decoded.hasPrefix("https://") {
            return stripTrackingParameters(from: decoded)
        }
        // Protocol-relative
        if decoded.hasPrefix("//"), let url = URL(string: "https:\(decoded)") {
            return stripTrackingParameters(from: url.absoluteString)
        }
        // Relative - needs base URL
        if let baseURL, let resolved = URL(string: decoded, relativeTo: baseURL) {
            return stripTrackingParameters(from: resolved.absoluteString)
        }
        return nil
    }

    /// Percent-decodes bare `&amp;` / `&#x26;` entity sequences commonly
    /// left in raw attribute values before handing the string to `URL`.
    private static func htmlEntityDecodedURL(_ src: String) -> String {
        guard src.contains("&") else { return src }
        return src
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#x26;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
    }

    private static let trackingParameterPrefixes: Set<String> = [
        "utm_", "mc_", "fbclid", "gclid", "dclid",
        "igshid", "oly_anon_id", "oly_enc_id", "ref_",
        "spm", "sourceid", "gs_lcrp"
    ]

    /// Strips known tracking query parameters while preserving everything
    /// else.  Improves cache-hit rate for images that differ only in their
    /// utm_* tags between pages.
    static func stripTrackingParameters(from absoluteString: String) -> String {
        guard var components = URLComponents(string: absoluteString),
              let queryItems = components.queryItems, !queryItems.isEmpty else {
            return absoluteString
        }
        let filtered = queryItems.filter { item in
            let lowered = item.name.lowercased()
            if trackingParameterPrefixes.contains(where: lowered.hasPrefix) {
                return false
            }
            return lowered != "fbclid" && lowered != "gclid"
                && lowered != "dclid" && lowered != "igshid"
        }
        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? absoluteString
    }

    /// Resolves relative URLs inside Markdown links (`[text](url)`) against a base URL.
    /// Also percent-encodes spaces in link URLs.
    static func resolveMarkdownLinks(in text: String, baseURL: URL?) -> String {
        guard let baseURL else { return text }
        let pattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            var url = nsText.substring(with: match.range(at: 2))
            if url.hasPrefix("http://") || url.hasPrefix("https://") { continue }
            url = url.replacingOccurrences(of: " ", with: "%20")
            if url.hasPrefix("//"), let abs = URL(string: "https:\(url)") {
                url = abs.absoluteString
            } else if let resolved = URL(string: url, relativeTo: baseURL) {
                url = resolved.absoluteString
            } else {
                continue
            }
            let linkText = nsText.substring(with: match.range(at: 1))
            let replacement = "[\(linkText)](\(url))"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
