import Foundation
import Hanami

extension ContentBlock {

    /// Strips block markers, returning plain text suitable for translation/summarization.
    nonisolated static func plainText(from text: String) -> String {
        let stripped = text.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{AUDIO\}\}.+?\{\{/AUDIO\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{YOUTUBE\}\}.+?\{\{/YOUTUBE\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{XPOST\}\}.+?\{\{/XPOST\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{EMBED\}\}.+?\{\{/EMBED\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"(?s)\{\{TABLE\}\}.+?\{\{/TABLE\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"(?s)\{\{DL\}\}.+?\{\{/DL\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{MATH\}\}.+?\{\{/MATH\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(of: "{{CODE}}", with: "")
        .replacingOccurrences(of: "{{/CODE}}", with: "")
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return ArticleMarker.unescape(stripped)
    }

    /// Strips Markdown formatting, returning plain text for content previews.
    nonisolated static func stripMarkdown(_ text: String) -> String {
        var result = text
        for (regex, template) in markdownStripRegexes {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: template
            )
        }
        result = result.replacingOccurrences(of: "{{CODE}}", with: "")
        result = result.replacingOccurrences(of: "{{/CODE}}", with: "")
        result = result.replacingOccurrences(of: "\\[", with: "[")
        result = result.replacingOccurrences(of: "\\]", with: "]")
        result = ArticleMarker.unescape(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static let markdownStripRegexes: [(NSRegularExpression, String)] =
        markdownStripPatterns.compactMap { pattern, replacement in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, replacement)
        }

    nonisolated private static let markdownStripPatterns: [(pattern: String, replacement: String)] = [
        (#"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, ""),
        (#"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, ""),
        (#"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, ""),
        (#"\{\{AUDIO\}\}.+?\{\{/AUDIO\}\}"#, ""),
        (#"\{\{YOUTUBE\}\}.+?\{\{/YOUTUBE\}\}"#, ""),
        (#"\{\{XPOST\}\}.+?\{\{/XPOST\}\}"#, ""),
        (#"\{\{EMBED\}\}.+?\{\{/EMBED\}\}"#, ""),
        (#"(?s)\{\{TABLE\}\}.+?\{\{/TABLE\}\}"#, ""),
        (#"(?s)\{\{DL\}\}.+?\{\{/DL\}\}"#, ""),
        (#"\{\{MATH\}\}(.+?)\{\{/MATH\}\}"#, "$1"),
        (#"\{\{SUP\}\}(.+?)\{\{/SUP\}\}"#, "$1"),
        (#"\{\{SUB\}\}(.+?)\{\{/SUB\}\}"#, "$1"),
        (#"\[((?:[^\]\\]|\\.)+)\]\([^)]+\)"#, "$1"),
        (#"\*\*(.+?)\*\*"#, "$1"),
        (#"\*(.+?)\*"#, "$1"),
        (#"(?m)^#{1,6}\s+"#, ""),
        (#"\n{3,}"#, "\n\n")
    ]
}
