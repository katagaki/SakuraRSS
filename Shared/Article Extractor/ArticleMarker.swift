import Foundation

/// Escapes literal `{{IMG}}`/`{{CODE}}`/etc. sequences in article text so
/// `ContentBlock.parse` doesn't misinterpret them as extractor markers.
/// Escaped form uses U+E000/U+E001 as delimiters so it contains no
/// `{{TOKEN}}` substring — callers checking `text.contains("{{IMG}}")`
/// keep matching only real markers.
nonisolated enum ArticleMarker {

    private static let table: [(literal: String, escaped: String)] = [
        ("{{IMG}}", "\u{E000}IMG\u{E001}"),
        ("{{/IMG}}", "\u{E000}/IMG\u{E001}"),
        ("{{IMGLINK}}", "\u{E000}IMGLINK\u{E001}"),
        ("{{/IMGLINK}}", "\u{E000}/IMGLINK\u{E001}"),
        ("{{CODE}}", "\u{E000}CODE\u{E001}"),
        ("{{/CODE}}", "\u{E000}/CODE\u{E001}"),
        ("{{VIDEO}}", "\u{E000}VIDEO\u{E001}"),
        ("{{/VIDEO}}", "\u{E000}/VIDEO\u{E001}"),
        ("{{YOUTUBE}}", "\u{E000}YOUTUBE\u{E001}"),
        ("{{/YOUTUBE}}", "\u{E000}/YOUTUBE\u{E001}"),
        ("{{XPOST}}", "\u{E000}XPOST\u{E001}"),
        ("{{/XPOST}}", "\u{E000}/XPOST\u{E001}"),
        ("{{EMBED}}", "\u{E000}EMBED\u{E001}"),
        ("{{/EMBED}}", "\u{E000}/EMBED\u{E001}"),
        ("{{TABLE}}", "\u{E000}TABLE\u{E001}"),
        ("{{/TABLE}}", "\u{E000}/TABLE\u{E001}"),
        ("{{MATH}}", "\u{E000}MATH\u{E001}"),
        ("{{/MATH}}", "\u{E000}/MATH\u{E001}"),
        ("{{SUP}}", "\u{E000}SUP\u{E001}"),
        ("{{/SUP}}", "\u{E000}/SUP\u{E001}"),
        ("{{SUB}}", "\u{E000}SUB\u{E001}"),
        ("{{/SUB}}", "\u{E000}/SUB\u{E001}")
    ]

    static func escape(_ text: String) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        for (literal, escaped) in table where result.contains(literal) {
            result = result.replacingOccurrences(of: literal, with: escaped)
        }
        return result
    }

    static func unescape(_ text: String) -> String {
        guard text.contains("\u{E000}") else { return text }
        var result = text
        for (literal, escaped) in table where result.contains(escaped) {
            result = result.replacingOccurrences(of: escaped, with: literal)
        }
        return result
    }
}
