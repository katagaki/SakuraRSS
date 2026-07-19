import Foundation
import FoundationModels

extension HeadlineSummarizer {

    // MARK: - Context Budget

    /// Upper bound on how much of a raw article body is worth processing
    /// for a snippet; full-content feeds can carry bodies of hundreds of
    /// kilobytes.
    static let rawSnippetSourceLimit = 4096

    /// Prepares an article body for prompting: strips HTML tags and
    /// entities, collapses whitespace, and trims to the weighted snippet
    /// budget so a CJK snippet costs roughly the same number of model
    /// tokens as a Latin one.
    public static func snippet(from raw: String) -> String {
        var text = String(raw.prefix(rawSnippetSourceLimit)).replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        let entities: [(String, String)] = [
            ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""),
            ("&#39;", "'"), ("&nbsp;", " "), ("&amp;", "&")
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return weightedPrefix(text, budget: snippetCharLimit)
    }

    static func weightedPromptLength(of text: String) -> Int {
        text.reduce(0) { total, character in
            total + weight(of: character)
        }
    }

    static func weightedPrefix(_ text: String, budget: Int) -> String {
        var cost = 0
        for index in text.indices {
            cost += weight(of: text[index])
            if cost > budget {
                return String(text[..<index])
            }
        }
        return text
    }

    /// CJK scripts encode roughly one model token per character while
    /// Latin text averages about four characters per token, so CJK
    /// characters count four times toward the character budget.
    private static func weight(of character: Character) -> Int {
        character.unicodeScalars.contains(where: isCJKScalar) ? 4 : 1
    }

    private static func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x2E80...0x9FFF,   // CJK radicals, kana, ideographs
             0xAC00...0xD7AF,   // Hangul syllables
             0xF900...0xFAFF,   // CJK compatibility ideographs
             0xFF00...0xFFEF:   // Fullwidth and halfwidth forms
            return true
        default:
            return false
        }
    }

    static func isContextWindowOverflow(_ error: Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = generationError {
            return true
        }
        return false
    }
}
