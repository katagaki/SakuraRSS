import Foundation

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

nonisolated private let maximumEntityLength = 12

nonisolated private let rssHTMLTagRegex = try? NSRegularExpression(
    pattern: #"</?[A-Za-z][^\s>]*(?:\s[^>]*?)?/?>|<!--[\s\S]*?-->|<![^>]*>|<\?[^>]*>"#
)

public nonisolated extension RSSParser {

    static func decodeHTMLEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }

        var result = ""
        result.reserveCapacity(string.count)
        var index = string.startIndex

        while index < string.endIndex {
            if string[index] == "&" {
                let entityStart = string.index(after: index)
                let limit = string.index(
                    entityStart, offsetBy: maximumEntityLength, limitedBy: string.endIndex
                ) ?? string.endIndex
                if let semicolonIndex = string[entityStart..<limit].firstIndex(of: ";"),
                   semicolonIndex > entityStart,
                   let decoded = decodeEntity(String(string[entityStart..<semicolonIndex])) {
                    result.append(decoded)
                    index = string.index(after: semicolonIndex)
                    continue
                }
            }

            result.append(string[index])
            index = string.index(after: index)
        }

        return result
    }

    static func decodeEntity(_ entity: String) -> String? {
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

    // Runs before entity decoding so literal angle brackets in decoded text survive
    static func stripHTMLTags(_ text: String) -> String {
        guard text.contains("<"), let regex = rssHTMLTagRegex else { return text }
        let nsText = text as NSString
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: nsText.length), withTemplate: ""
        )
    }
}
