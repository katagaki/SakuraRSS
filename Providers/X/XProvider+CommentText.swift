import Foundation

nonisolated extension XProvider {

    /// Trims the leading @mention chain from an X reply's `full_text` so the
    /// displayed comment starts at the substantive content. X uses the leading
    /// `@handle` tokens for threading and indicates the first non-mention
    /// character via `display_text_range[0]` (a UTF-16 code-unit offset).
    static func stripLeadingMentions(
        fullText: String, displayTextRange: [Int]?
    ) -> String {
        let preferred = sliceByDisplayTextRange(fullText, range: displayTextRange)
            ?? stripLeadingMentionsFallback(fullText)
        return decodeHTMLEntities(preferred.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// X's API returns `full_text` with HTML-encoded `&`, `<`, `>`, so the
    /// raw string contains tokens like `&amp;` that need decoding before
    /// display.
    static func decodeHTMLEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Slices `fullText` using UTF-16 offsets  X's `display_text_range`
    /// indices count UTF-16 code units.
    private static func sliceByDisplayTextRange(
        _ text: String, range: [Int]?
    ) -> String? {
        guard let range, range.count == 2 else { return nil }
        let utf16 = text.utf16
        let start = max(0, range[0])
        let end = max(start, range[1])
        guard end <= utf16.count else { return nil }
        guard let startUTF16 = utf16.index(
                utf16.startIndex, offsetBy: start, limitedBy: utf16.endIndex
              ),
              let endUTF16 = utf16.index(
                utf16.startIndex, offsetBy: end, limitedBy: utf16.endIndex
              ),
              let startIndex = String.Index(startUTF16, within: text),
              let endIndex = String.Index(endUTF16, within: text) else {
            return nil
        }
        return String(text[startIndex..<endIndex])
    }

    private static func stripLeadingMentionsFallback(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"^(\s*@[A-Za-z0-9_]+)+\s*"#,
            with: "",
            options: .regularExpression
        )
    }
}
