import Foundation

// MARK: - HTML Entity Decoding

nonisolated private let htmlNamedEntities: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
    "nbsp": "\u{00A0}", "iexcl": "\u{00A1}", "cent": "\u{00A2}",
    "pound": "\u{00A3}", "curren": "\u{00A4}", "yen": "\u{00A5}",
    "brvbar": "\u{00A6}", "sect": "\u{00A7}", "uml": "\u{00A8}",
    "copy": "\u{00A9}", "ordf": "\u{00AA}", "laquo": "\u{00AB}",
    "not": "\u{00AC}", "shy": "\u{00AD}", "reg": "\u{00AE}",
    "macr": "\u{00AF}", "deg": "\u{00B0}", "plusmn": "\u{00B1}",
    "sup2": "\u{00B2}", "sup3": "\u{00B3}", "acute": "\u{00B4}",
    "micro": "\u{00B5}", "para": "\u{00B6}", "middot": "\u{00B7}",
    "cedil": "\u{00B8}", "sup1": "\u{00B9}", "ordm": "\u{00BA}",
    "raquo": "\u{00BB}", "frac14": "\u{00BC}", "frac12": "\u{00BD}",
    "frac34": "\u{00BE}", "iquest": "\u{00BF}",
    "times": "\u{00D7}", "divide": "\u{00F7}",
    "ndash": "\u{2013}", "mdash": "\u{2014}",
    "lsquo": "\u{2018}", "rsquo": "\u{2019}",
    "sbquo": "\u{201A}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
    "bdquo": "\u{201E}", "dagger": "\u{2020}", "Dagger": "\u{2021}",
    "bull": "\u{2022}", "hellip": "\u{2026}",
    "permil": "\u{2030}", "prime": "\u{2032}", "Prime": "\u{2033}",
    "lsaquo": "\u{2039}", "rsaquo": "\u{203A}",
    "oline": "\u{203E}", "frasl": "\u{2044}",
    "euro": "\u{20AC}", "trade": "\u{2122}",
    "larr": "\u{2190}", "uarr": "\u{2191}", "rarr": "\u{2192}", "darr": "\u{2193}",
    "harr": "\u{2194}", "lArr": "\u{21D0}", "uArr": "\u{21D1}",
    "rArr": "\u{21D2}", "dArr": "\u{21D3}", "hArr": "\u{21D4}",
    "minus": "\u{2212}", "lowast": "\u{2217}",
    "le": "\u{2264}", "ge": "\u{2265}", "ne": "\u{2260}",
    "equiv": "\u{2261}", "sum": "\u{2211}", "prod": "\u{220F}",
    "infin": "\u{221E}", "radic": "\u{221A}",
    "spades": "\u{2660}", "clubs": "\u{2663}",
    "hearts": "\u{2665}", "diams": "\u{2666}"
]

nonisolated extension RSSParser {

    func decodeHTMLEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }

        var result = ""
        var index = string.startIndex

        while index < string.endIndex {
            if string[index] == "&",
               let semiIndex = string[index...].firstIndex(of: ";"),
               semiIndex > string.index(after: index) {
                let entity = String(string[string.index(after: index)..<semiIndex])

                if let decoded = decodeEntity(entity) {
                    result.append(decoded)
                    index = string.index(after: semiIndex)
                    continue
                }
            }

            result.append(string[index])
            index = string.index(after: index)
        }

        return result
    }

    func decodeEntity(_ entity: String) -> String? {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = String(entity.dropFirst(2))
            if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
        } else if entity.hasPrefix("#") {
            let decimal = String(entity.dropFirst())
            if let code = UInt32(decimal), let scalar = Unicode.Scalar(code) {
                return String(Character(scalar))
            }
        } else if let replacement = htmlNamedEntities[entity] {
            return replacement
        }
        return nil
    }

    func cleanHTML(_ html: String) -> String? {
        let stripped = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = decodeHTMLEntities(stripped)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? nil : decoded
    }

    /// Converts HTML to plain text, preserving structure with newlines and Markdown links.
    func cleanHTMLPreservingStructure(_ html: String, baseURL: URL? = nil) -> String? {
        guard html.contains("<") else {
            let decoded = decodeHTMLEntities(html).trimmingCharacters(in: .whitespacesAndNewlines)
            return decoded.isEmpty ? nil : decoded
        }

        var result = html
        result = result.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: .regularExpression
        )
        result = convertLinksToMarkdown(result, baseURL: baseURL)
        result = convertInlineMarkup(result)
        result = stripInvalidURLSupSub(result)

        let blockTags = ["p", "div", "li"]
        for tag in blockTags {
            result = result.replacingOccurrences(
                of: "</\(tag)>", with: "\n", options: .caseInsensitive
            )
        }

        result = replacePreTagsWithMarkers(result)
        result = replaceImgTagsWithMarkers(result)
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = decodeHTMLEntities(result)
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )

        result = result
            .components(separatedBy: "\n")
            .filter { !AdvertisementTextFilter.isAdvertisementText($0) }
            .joined(separator: "\n")

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Converts `<a>` tags to Markdown links, resolving relative URLs against `baseURL`.
    private func convertLinksToMarkdown(_ text: String, baseURL: URL? = nil) -> String {
        guard let linkRegex = try? NSRegularExpression(
            pattern: #"<a\s[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#
        ) else { return text }

        var result = text
        let nsResult = result as NSString
        let linkMatches = linkRegex.matches(
            in: result, range: NSRange(location: 0, length: nsResult.length)
        )
        for match in linkMatches.reversed() {
            var url = nsResult.substring(with: match.range(at: 1))
            let linkText = nsResult.substring(with: match.range(at: 2))
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if linkText.isEmpty {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            } else {
                url = url.replacingOccurrences(of: " ", with: "%20")
                if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                    if url.hasPrefix("//"), let abs = URL(string: "https:\(url)") {
                        url = abs.absoluteString
                    } else if let baseURL, let resolved = URL(string: url, relativeTo: baseURL) {
                        url = resolved.absoluteString
                    }
                }
                let escaped = linkText
                    .replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
                let replacement = "[\(escaped)](\(url))"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    /// Converts inline HTML tags (headers, bold, italic, sup, sub, code) to Markdown.
    private func convertInlineMarkup(_ text: String) -> String {
        var result = text

        result = result.replacingOccurrences(
            of: #"<h1(?:\s[^>]*)?>(.+?)</h1>"#, with: "\n# $1\n",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<h2(?:\s[^>]*)?>(.+?)</h2>"#, with: "\n## $1\n",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<h3(?:\s[^>]*)?>(.+?)</h3>"#, with: "\n### $1\n",
            options: [.regularExpression, .caseInsensitive]
        )
        for tag in ["h4", "h5", "h6"] {
            result = result.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", with: "\n**$1**\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        for tag in ["strong", "b"] {
            result = result.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", with: "**$1**",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        for tag in ["em"] {
            result = result.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", with: "*$1*",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        result = result.replacingOccurrences(
            of: #"<i(?:\s[^>]*)?>(.+?)</i>"#, with: "*$1*",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<sup(?:\s[^>]*)?>(.+?)</sup>"#, with: "{{SUP}}$1{{/SUP}}",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<sub(?:\s[^>]*)?>(.+?)</sub>"#, with: "{{SUB}}$1{{/SUB}}",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: #"<code(?:\s[^>]*)?>(.+?)</code>"#, with: "`$1`",
            options: [.regularExpression, .caseInsensitive]
        )
        return result
    }

    func extractImageFromHTML(_ html: String) -> String? {
        let patterns = [
            #"<img[^>]+src="([^"]+)""#,
            #"<img[^>]+src='([^']+)'"#
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = html[range]
                if let srcRange = match.range(of: #"src=["']([^"']+)["']"#, options: .regularExpression) {
                    let src = match[srcRange]
                    let url = src.dropFirst(5).dropLast(1)
                    let urlString = String(url)
                    if isLikelyHeroImage(urlString) {
                        return urlString
                    }
                }
            }
        }
        for pattern in patterns {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = html[range]
                if let srcRange = match.range(of: #"src=["']([^"']+)["']"#, options: .regularExpression) {
                    let src = match[srcRange]
                    let url = src.dropFirst(5).dropLast(1)
                    return String(url)
                }
            }
        }
        return nil
    }

    /// Removes SUP/SUB markers whose content contains an invalid URL.
    func stripInvalidURLSupSub(_ text: String) -> String {
        let pattern = #"\{\{(SUP|SUB)\}\}(.+?)\{\{/(SUP|SUB)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let content = nsText.substring(with: match.range(at: 2))
            let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
            if let linkRegex = try? NSRegularExpression(pattern: linkPattern),
               let linkMatch = linkRegex.firstMatch(
                in: content, range: NSRange(location: 0, length: (content as NSString).length)
               ) {
                let urlString = (content as NSString).substring(with: linkMatch.range(at: 2))
                if URL(string: urlString) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            } else if content.hasPrefix("http://") || content.hasPrefix("https://")
                        || content.hasPrefix("//") {
                if URL(string: content) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        return result
    }

    /// Converts `<pre>` blocks to `{{CODE}}...{{/CODE}}` markers.
    private func replacePreTagsWithMarkers(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"<pre(?:\s[^>]*)?>(?:\s*<code(?:\s[^>]*)?>)?(.*?)(?:</code>\s*)?</pre>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return text }
        var result = text
        let nsResult = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            var content = nsResult.substring(with: match.range(at: 1))
            content = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            content = content.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            if !content.isEmpty {
                let replacement = "\n{{CODE}}\(content){{/CODE}}\n"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    private func replaceImgTagsWithMarkers(_ text: String) -> String {
        let imgPattern = #"<img\s[^>]*src=["']([^"']+)["'][^>]*>"#
        guard let imgRegex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive)
        else { return text }
        var result = text
        let nsResult = result as NSString
        let matches = imgRegex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            let imgURL = nsResult.substring(with: match.range(at: 1))
            if isLikelyHeroImage(imgURL) {
                let replacement = "\n{{IMG}}\(imgURL){{/IMG}}\n"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            } else {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    private func isLikelyHeroImage(_ url: String) -> Bool {
        let lowered = url.lowercased()
        let skipPatterns = [
            "gravatar.com", "pixel", "spacer", "blank",
            "1x1", "transparent", "tracking", "beacon",
            ".gif", "feeds.feedburner.com", "badge",
            "icon", "emoji", "smiley", "avatar",
            "ad.", "ads.", "doubleclick", "googlesyndication"
        ]
        for pattern in skipPatterns {
            if lowered.contains(pattern) { return false } // swiftlint:disable:this for_where
        }
        return true
    }
}
