import Foundation

/// Fallback image lookup for RSS items that ship without any image tag.
/// Fetches the article page's `<head>` and returns the first usable
/// `og:image` / `twitter:image` / `image_src` / `itemprop=image`.
nonisolated enum HTMLMetadataImage {

    /// Cap the body read so a large article HTML can't be pulled down
    /// just to find a meta tag near the top of `<head>`.
    private static let maxBytes = 128 * 1024

    static func fetchImageURL(
        for articleURL: URL,
        timeout: TimeInterval = 5
    ) async -> String? {
        guard let scheme = articleURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        var request = URLRequest(url: articleURL, timeoutInterval: timeout)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            let slice = data.prefix(maxBytes)
            guard let html = String(data: slice, encoding: .utf8)
                    ?? String(data: slice, encoding: .isoLatin1) else {
                return nil
            }
            return extractImageURL(from: html, baseURL: response.url ?? articleURL)
        } catch {
            return nil
        }
    }

    static func extractImageURL(from html: String, baseURL: URL?) -> String? {
        // Restrict scanning to <head> when possible so inline article
        // images don't get picked up as false positives.
        let headSlice: String = {
            if let range = html.range(of: "</head>", options: .caseInsensitive) {
                return String(html[..<range.lowerBound])
            }
            return html
        }()

        // Ordered best-to-worst; first hit wins.
        let metaNamePatterns = [
            "og:image:secure_url",
            "og:image:url",
            "og:image",
            "twitter:image:src",
            "twitter:image"
        ]

        for name in metaNamePatterns {
            if let value = findMetaContent(in: headSlice, propertyOrName: name),
               let resolved = resolveURL(value, against: baseURL) {
                return resolved
            }
        }

        if let linkHref = findLinkHref(in: headSlice, rel: "image_src"),
           let resolved = resolveURL(linkHref, against: baseURL) {
            return resolved
        }

        if let itemprop = findItempropContent(in: headSlice, itemprop: "image"),
           let resolved = resolveURL(itemprop, against: baseURL) {
            return resolved
        }

        return nil
    }

    // MARK: - Tag Matching

    private static func findMetaContent(
        in html: String, propertyOrName name: String
    ) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        // Two attribute orderings — HTML doesn't fix the order.
        let patterns = [
            #"<meta\b[^>]*?\b(?:property|name)\s*=\s*["']\#(escaped)["'][^>]*?\bcontent\s*=\s*["']([^"']+)["']"#,
            #"<meta\b[^>]*?\bcontent\s*=\s*["']([^"']+)["'][^>]*?\b(?:property|name)\s*=\s*["']\#(escaped)["']"#
        ]
        return firstNonEmptyCapture(in: html, patterns: patterns)
    }

    private static func findLinkHref(in html: String, rel: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: rel)
        let patterns = [
            #"<link\b[^>]*?\brel\s*=\s*["']\#(escaped)["'][^>]*?\bhref\s*=\s*["']([^"']+)["']"#,
            #"<link\b[^>]*?\bhref\s*=\s*["']([^"']+)["'][^>]*?\brel\s*=\s*["']\#(escaped)["']"#
        ]
        return firstNonEmptyCapture(in: html, patterns: patterns)
    }

    private static func findItempropContent(
        in html: String, itemprop: String
    ) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: itemprop)
        let patterns = [
            #"<meta\b[^>]*?\bitemprop\s*=\s*["']\#(escaped)["'][^>]*?\bcontent\s*=\s*["']([^"']+)["']"#,
            #"<meta\b[^>]*?\bcontent\s*=\s*["']([^"']+)["'][^>]*?\bitemprop\s*=\s*["']\#(escaped)["']"#
        ]
        return firstNonEmptyCapture(in: html, patterns: patterns)
    }

    private static func firstNonEmptyCapture(in html: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let value = firstCaptureGroup(in: html, pattern: pattern) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func firstCaptureGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2 else { return nil }
        let groupRange = match.range(at: 1)
        guard groupRange.location != NSNotFound else { return nil }
        return nsText.substring(with: groupRange)
    }

    private static func resolveURL(_ raw: String, against baseURL: URL?) -> String? {
        let decoded = decodeBasicHTMLEntities(raw)
        if decoded.hasPrefix("http://") || decoded.hasPrefix("https://") {
            return URL(string: decoded) == nil ? nil : decoded
        }
        if decoded.hasPrefix("//"), let url = URL(string: "https:\(decoded)") {
            return url.absoluteString
        }
        if let baseURL, let resolved = URL(string: decoded, relativeTo: baseURL) {
            return resolved.absoluteString
        }
        return nil
    }

    private static func decodeBasicHTMLEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&#38;", with: "&")
        result = result.replacingOccurrences(of: "&#x26;", with: "&")
        return result
    }
}
