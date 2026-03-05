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

    /// Converts HTML to plain text, preserving paragraph/heading structure as newlines
    /// and rendering `<a>` links as "text (url)".
    func cleanHTMLPreservingStructure(_ html: String) -> String? {
        guard html.contains("<") else {
            let decoded = decodeHTMLEntities(html).trimmingCharacters(in: .whitespacesAndNewlines)
            return decoded.isEmpty ? nil : decoded
        }

        var result = html

        // Replace <br> variants with newlines
        result = result.replacingOccurrences(
            of: #"<br\s*/?>"#, with: "\n", options: .regularExpression
        )

        // Convert <a href="url">text</a> to "text (url)"
        result = result.replacingOccurrences(
            of: #"<a\s[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#,
            with: "$2 ($1)", options: .regularExpression
        )

        // Add newlines after block-level closing tags
        let blockTags = ["p", "h1", "h2", "h3", "h4", "h5", "h6", "div", "li"]
        for tag in blockTags {
            result = result.replacingOccurrences(
                of: "</\(tag)>", with: "\n", options: .caseInsensitive
            )
        }

        // Strip remaining HTML tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode HTML entities
        result = decodeHTMLEntities(result)

        // Collapse multiple consecutive newlines into two
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    func extractImageFromHTML(_ html: String) -> String? {
        // Try double-quoted src first, then single-quoted
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
        // No hero-quality image found, return first image as fallback
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

    private func isLikelyHeroImage(_ url: String) -> Bool {
        let lowered = url.lowercased()
        // Skip tracking pixels, icons, and spacers
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
