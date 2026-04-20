import Foundation
@preconcurrency import Translation

extension ContentBlock {

    /// A contiguous slice of marker-encoded article text for translation purposes.
    enum TranslationSegment {
        /// Plain text between markers — safe to send to the translator.
        case translatable(String)
        /// A `{{TAG}}...{{/TAG}}` block whose payload must be preserved verbatim.
        case preserved(String)
    }

    /// Splits marker-encoded text into translatable spans and preserved marker blocks.
    /// Translatable spans contain everything outside of `{{IMG}}`, `{{CODE}}`, `{{VIDEO}}`,
    /// `{{YOUTUBE}}`, `{{XPOST}}`, `{{EMBED}}`, `{{TABLE}}`, and `{{MATH}}` markers.
    static func translationSegments(from text: String) -> [TranslationSegment] {
        let pattern = #"\{\{(IMG|CODE|VIDEO|YOUTUBE|XPOST|EMBED|TABLE|MATH)\}\}.*?\{\{/\1\}\}"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: .dotMatchesLineSeparators
        ) else {
            return text.isEmpty ? [] : [.translatable(text)]
        }

        // Mirror `ContentBlock.parse`: if the as-is pass finds no markers
        // but the text carries PUA-escaped delimiters, reparse against the
        // unescaped form so image/code/embed blocks stay preserved instead
        // of being fed into the translator as opaque Unicode runs.
        var nsText = text as NSString
        var matches = regex.matches(
            in: text, range: NSRange(location: 0, length: nsText.length)
        )

        if matches.isEmpty && text.contains("\u{E000}") {
            let unescaped = ArticleMarker.unescape(text)
            let nsUnescaped = unescaped as NSString
            let retry = regex.matches(
                in: unescaped,
                range: NSRange(location: 0, length: nsUnescaped.length)
            )
            if !retry.isEmpty {
                nsText = nsUnescaped
                matches = retry
            }
        }

        guard !matches.isEmpty else {
            return text.isEmpty ? [] : [.translatable(text)]
        }

        var segments: [TranslationSegment] = []
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(
                    with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                )
                if !before.isEmpty {
                    segments.append(.translatable(before))
                }
            }
            segments.append(.preserved(nsText.substring(with: match.range)))
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let after = nsText.substring(from: lastEnd)
            if !after.isEmpty {
                segments.append(.translatable(after))
            }
        }

        return segments
    }

    /// Translates marker-encoded article text one text block at a time, batching all text blocks
    /// (and the optional title) into a single `session.translations(from:)` call so non-text
    /// blocks (images, code, tables, embeds, math) are preserved verbatim in the output.
    static func translateArticleContent(
        title: String?, markerText: String, session: TranslationSession
    ) async throws -> (title: String?, text: String) {
        let segments = translationSegments(from: markerText)

        let titleIdentifier = "title"
        var requests: [TranslationSession.Request] = []

        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requests.append(
                TranslationSession.Request(sourceText: title, clientIdentifier: titleIdentifier)
            )
        }

        for (index, segment) in segments.enumerated() {
            guard case .translatable(let content) = segment,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            requests.append(
                TranslationSession.Request(
                    sourceText: content, clientIdentifier: segmentIdentifier(for: index)
                )
            )
        }

        guard !requests.isEmpty else {
            return (title: title, text: markerText)
        }

        let responses = try await session.translations(from: requests)
        var translatedTitle: String? = title
        var translatedSegments: [Int: String] = [:]

        for response in responses {
            guard let identifier = response.clientIdentifier else { continue }
            if identifier == titleIdentifier {
                translatedTitle = response.targetText
            } else if let index = segmentIndex(from: identifier) {
                translatedSegments[index] = response.targetText
            }
        }

        var rebuilt = ""
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .translatable(let original):
                rebuilt += translatedSegments[index] ?? original
            case .preserved(let marker):
                rebuilt += marker
            }
        }

        return (title: translatedTitle, text: rebuilt)
    }

    private static let segmentIdentifierPrefix = "seg-"

    private static func segmentIdentifier(for index: Int) -> String {
        "\(segmentIdentifierPrefix)\(index)"
    }

    private static func segmentIndex(from identifier: String) -> Int? {
        guard identifier.hasPrefix(segmentIdentifierPrefix) else { return nil }
        return Int(identifier.dropFirst(segmentIdentifierPrefix.count))
    }
}
