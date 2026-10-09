import Foundation

/// Converts HTML `<ruby>` (furigana) into `{{RUBY}}base{{RT}}reading{{/RUBY}}` markers.
public nonisolated enum RubyMarkup {

    public static let openMarker = "{{RUBY}}"
    public static let readingMarker = "{{RT}}"
    public static let closeMarker = "{{/RUBY}}"

    static let markerRegex = try? NSRegularExpression(
        pattern: #"\{\{RUBY\}\}(.+?)\{\{RT\}\}(.+?)\{\{/RUBY\}\}"#
    )

    private static let rubyElementRegex = try? NSRegularExpression(
        pattern: #"<ruby(?:\s[^>]*)?>(.*?)</ruby>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    private static let readingPairRegex = try? NSRegularExpression(
        pattern: #"(.*?)<rt(?:\s[^>]*)?>(.*?)</rt>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    public static func containsRuby(_ text: String) -> Bool {
        text.contains(openMarker)
    }

    /// Replaces `<ruby>` elements with markers, dropping `<rp>` fallback parentheses.
    public static func convertRubyTags(
        in html: String,
        open: String = openMarker,
        reading: String = readingMarker,
        close: String = closeMarker
    ) -> String {
        guard html.range(of: "<ruby", options: .caseInsensitive) != nil,
              let rubyElementRegex else { return html }
        let nsHTML = html as NSString
        let matches = rubyElementRegex.matches(
            in: html, range: NSRange(location: 0, length: nsHTML.length)
        )
        var result = html
        for match in matches.reversed() {
            let inner = nsHTML.substring(with: match.range(at: 1))
            let replacement = markedText(
                fromRubyContents: inner, open: open, reading: reading, close: close
            )
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    /// Keeps the base text and drops the readings, for plain-text uses.
    public static func strippingReadings(_ text: String) -> String {
        guard containsRuby(text), let markerRegex else { return text }
        return markerRegex.stringByReplacingMatches(
            in: text,
            range: NSRange(location: 0, length: (text as NSString).length),
            withTemplate: "$1"
        )
    }

    private static func markedText(
        fromRubyContents contents: String, open: String, reading: String, close: String
    ) -> String {
        let cleaned = contents
            .replacingOccurrences(
                of: #"<rp(?:\s[^>]*)?>.*?</rp>"#, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .replacingOccurrences(
                of: #"</?(?:rb|rtc)(?:\s[^>]*)?>"#, with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        guard let readingPairRegex else { return withoutTags(cleaned) }
        let nsCleaned = cleaned as NSString
        var result = ""
        var lastEnd = 0
        for pair in readingPairRegex.matches(
            in: cleaned, range: NSRange(location: 0, length: nsCleaned.length)
        ) {
            let base = withoutTags(nsCleaned.substring(with: pair.range(at: 1)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let readingText = withoutTags(nsCleaned.substring(with: pair.range(at: 2)))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if base.isEmpty || readingText.isEmpty {
                result += base
            } else {
                result += "\(open)\(base)\(reading)\(readingText)\(close)"
            }
            lastEnd = pair.range.location + pair.range.length
        }
        result += withoutTags(nsCleaned.substring(from: lastEnd))
        return result
    }

    private static func withoutTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
