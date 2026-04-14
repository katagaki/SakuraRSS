import Foundation

/// Fetches a page's `<head>` and extracts a representative image URL from
/// its metadata tags.  Used as a fallback when an RSS item ships without an
/// `<enclosure>`, `media:thumbnail`, `itunes:image`, or inline `<img>` —
/// most modern news sites still emit an `og:image` even when the feed does
/// not carry an image, so we can recover a thumbnail just by reading the
/// article's own HTML metadata.
///
/// The fetcher is intentionally conservative: it caps the download size,
/// uses a short timeout, and stops parsing once `</head>` is seen so that a
/// large article body is never transferred just to find a meta tag.
nonisolated enum HTMLMetadataImage {

    /// Maximum number of bytes to read from the page before giving up.
    /// Metadata lives in `<head>`, which is almost always within the first
    /// few kilobytes, so 128 KB is a comfortable upper bound that still
    /// protects against runaway downloads on pathological pages.
    private static let maxBytes = 128 * 1024

    /// Fetches `articleURL` and returns an absolute image URL extracted
    /// from its `<head>` metadata, or `nil` if none could be found.
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
        // Hint that we only want HTML.  Servers that negotiate on Accept
        // will skip sending us binary variants for the same URL.
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
            let resolvedBase = (response.url ?? articleURL)
            return extractImageURL(from: html, baseURL: resolvedBase)
        } catch {
            return nil
        }
    }

    /// Parses `<head>` metadata from an HTML string and returns the best
    /// candidate image URL, resolved against `baseURL` when the candidate
    /// is relative.  Returns `nil` if no usable image is found.
    static func extractImageURL(from html: String, baseURL: URL?) -> String? {
        // Only scan the `<head>` section when present — metadata lives
        // there and scanning the rest of the document can introduce false
        // positives from inline content images.
        let headSlice: String = {
            if let range = html.range(of: "</head>", options: .caseInsensitive) {
                return String(html[..<range.lowerBound])
            }
            return html
        }()

        // Ordered by quality: og:image* beats twitter:image beats
        // link rel=image_src beats itemprop=image.  The first hit wins.
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

    /// Matches `<meta ... property="<name>" ... content="...">` or
    /// `<meta ... name="<name>" ... content="...">` in either attribute
    /// order.  Property/name and content may appear in any order.
    private static func findMetaContent(
        in html: String, propertyOrName name: String
    ) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: name)
        // Two orderings: identifier before content, or content before
        // identifier.  HTML spec doesn't require a particular order.
        let patterns = [
            #"<meta\b[^>]*?\b(?:property|name)\s*=\s*["']\#(escaped)["'][^>]*?\bcontent\s*=\s*["']([^"']+)["']"#,
            #"<meta\b[^>]*?\bcontent\s*=\s*["']([^"']+)["'][^>]*?\b(?:property|name)\s*=\s*["']\#(escaped)["']"#
        ]
        for pattern in patterns {
            if let value = firstCaptureGroup(in: html, pattern: pattern) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    /// Matches `<link rel="<rel>" href="...">` in either attribute order.
    private static func findLinkHref(in html: String, rel: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: rel)
        let patterns = [
            #"<link\b[^>]*?\brel\s*=\s*["']\#(escaped)["'][^>]*?\bhref\s*=\s*["']([^"']+)["']"#,
            #"<link\b[^>]*?\bhref\s*=\s*["']([^"']+)["'][^>]*?\brel\s*=\s*["']\#(escaped)["']"#
        ]
        for pattern in patterns {
            if let value = firstCaptureGroup(in: html, pattern: pattern) {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    /// Matches `<meta itemprop="<name>" content="...">` for the schema.org
    /// microdata fallback used by a few publishers (notably Google AMP).
    private static func findItempropContent(
        in html: String, itemprop: String
    ) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: itemprop)
        let patterns = [
            #"<meta\b[^>]*?\bitemprop\s*=\s*["']\#(escaped)["'][^>]*?\bcontent\s*=\s*["']([^"']+)["']"#,
            #"<meta\b[^>]*?\bcontent\s*=\s*["']([^"']+)["'][^>]*?\bitemprop\s*=\s*["']\#(escaped)["']"#
        ]
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

    /// Resolves a candidate URL string to an absolute URL, handling
    /// protocol-relative (`//host/path`) and relative forms.  Also
    /// decodes the small set of HTML entities that commonly appear in
    /// meta `content=` attributes.
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
