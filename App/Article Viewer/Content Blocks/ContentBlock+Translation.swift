import Foundation
import Hanami
#if !os(visionOS)
@preconcurrency import Translation
#endif

#if !os(visionOS)
extension ContentBlock {

    enum TranslationSegment {
        case translatable(String)
        case preserved(String)
    }

    /// Splits marker-encoded text into translatable spans and preserved marker blocks.
    static func translationSegments(from text: String) -> [TranslationSegment] {
        let pattern = #"\{\{(IMG|CODE|VIDEO|YOUTUBE|XPOST|EMBED|TABLE|DL|MATH)\}\}.*?\{\{/\1\}\}"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: .dotMatchesLineSeparators
        ) else {
            return text.isEmpty ? [] : [.translatable(text)]
        }

        let (nsText, matches) = ArticleMarker.regexMatches(of: regex, in: text)

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

    static func translateArticleContent(
        title: String?, markerText: String, session: TranslationSession
    ) async throws -> (title: String?, text: String) {
        let segments = translationSegments(from: markerText)
        let requests = translationRequests(title: title, segments: segments)

        guard !requests.isEmpty else {
            return (title: title, text: markerText)
        }

        let responses = try await session.translations(from: requests)
        let (translatedTitle, translatedSegments) = mapTranslationResponses(
            responses, fallbackTitle: title
        )
        let rebuilt = rebuildMarkerText(segments: segments, translatedSegments: translatedSegments)
        return (title: translatedTitle, text: rebuilt)
    }

    private nonisolated static let titleClientIdentifier = "title"

    private nonisolated static func translationRequests(
        title: String?, segments: [TranslationSegment]
    ) -> [TranslationSession.Request] {
        var requests: [TranslationSession.Request] = []
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requests.append(
                TranslationSession.Request(
                    sourceText: title, clientIdentifier: titleClientIdentifier
                )
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
        return requests
    }

    private static func mapTranslationResponses(
        _ responses: [TranslationSession.Response], fallbackTitle: String?
    ) -> (title: String?, segments: [Int: String]) {
        var translatedTitle: String? = fallbackTitle
        var translatedSegments: [Int: String] = [:]
        for response in responses {
            guard let identifier = response.clientIdentifier else { continue }
            if identifier == titleClientIdentifier {
                translatedTitle = response.targetText
            } else if let index = segmentIndex(from: identifier) {
                translatedSegments[index] = response.targetText
            }
        }
        return (translatedTitle, translatedSegments)
    }

    private static func rebuildMarkerText(
        segments: [TranslationSegment], translatedSegments: [Int: String]
    ) -> String {
        var rebuilt = ""
        for (index, segment) in segments.enumerated() {
            switch segment {
            case .translatable(let original):
                rebuilt += translatedSegments[index] ?? original
            case .preserved(let marker):
                rebuilt += marker
            }
        }
        return rebuilt
    }

    private nonisolated static let segmentIdentifierPrefix = "seg-"

    private nonisolated static func segmentIdentifier(for index: Int) -> String {
        "\(segmentIdentifierPrefix)\(index)"
    }

    private nonisolated static func segmentIndex(from identifier: String) -> Int? {
        guard identifier.hasPrefix(segmentIdentifierPrefix) else { return nil }
        return Int(identifier.dropFirst(segmentIdentifierPrefix.count))
    }
}
#endif
