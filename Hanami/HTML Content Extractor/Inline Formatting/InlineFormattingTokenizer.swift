import Foundation

nonisolated struct InlineFormattingTokenizer {

    private typealias Extractor = HTMLContentExtractor

    private(set) var segments: [InlineFormattingSegment] = []
    private var boldDepth = 0
    private var italicDepth = 0
    private var linkStartIndex: Int?

    static func segments(from text: String) -> [InlineFormattingSegment] {
        var tokenizer = InlineFormattingTokenizer()
        var remaining = text[...]
        while let braceRange = remaining.range(of: "{{") {
            tokenizer.appendText(remaining[remaining.startIndex..<braceRange.lowerBound])
            remaining = tokenizer.consumeMarker(remaining[braceRange.lowerBound...])
        }
        tokenizer.appendText(remaining)
        return tokenizer.segments
    }

    private mutating func consumeMarker(_ marker: Substring) -> Substring {
        if let rest = consumeEmphasis(marker) {
            return rest
        }
        if marker.hasPrefix(Extractor.linkOpenPlaceholder) {
            linkStartIndex = linkStartIndex ?? segments.count
            return marker.dropFirst(Extractor.linkOpenPlaceholder.count)
        }
        if let (url, rest) = Self.enclosedText(
            in: marker, open: Extractor.linkMidPlaceholder, close: Extractor.linkClosePlaceholder
        ) {
            applyLinkURL(url)
            return rest
        }
        if let (code, rest) = Self.enclosedText(
            in: marker, open: Extractor.codeOpenPlaceholder, close: Extractor.codeClosePlaceholder
        ) {
            segments.append(InlineFormattingSegment(
                text: code, kind: .codeSpan, isBold: boldDepth > 0, isItalic: italicDepth > 0, linkURL: nil
            ))
            return rest
        }
        if let (markerText, rest) = Self.articleMarkerRegion(in: marker) {
            segments.append(.marker(markerText))
            return rest
        }
        appendText(marker.prefix(2))
        return marker.dropFirst(2)
    }

    private mutating func consumeEmphasis(_ marker: Substring) -> Substring? {
        if marker.hasPrefix(Extractor.boldOpenPlaceholder) {
            boldDepth += 1
            return marker.dropFirst(Extractor.boldOpenPlaceholder.count)
        }
        if marker.hasPrefix(Extractor.boldClosePlaceholder) {
            boldDepth = max(0, boldDepth - 1)
            return marker.dropFirst(Extractor.boldClosePlaceholder.count)
        }
        if marker.hasPrefix(Extractor.italicOpenPlaceholder) {
            italicDepth += 1
            return marker.dropFirst(Extractor.italicOpenPlaceholder.count)
        }
        if marker.hasPrefix(Extractor.italicClosePlaceholder) {
            italicDepth = max(0, italicDepth - 1)
            return marker.dropFirst(Extractor.italicClosePlaceholder.count)
        }
        return nil
    }

    private mutating func appendText(_ text: Substring) {
        for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            if index > 0 {
                segments.append(.marker("\n"))
            }
            guard !line.isEmpty else { continue }
            segments.append(InlineFormattingSegment(
                text: String(line), isBold: boldDepth > 0, isItalic: italicDepth > 0, linkURL: nil
            ))
        }
    }

    private mutating func applyLinkURL(_ url: String) {
        if let startIndex = linkStartIndex {
            for index in startIndex..<segments.count where segments[index].kind != .marker {
                segments[index].linkURL = url
            }
        }
        linkStartIndex = nil
    }

    private static func enclosedText(
        in text: Substring, open: String, close: String
    ) -> (String, Substring)? {
        guard text.hasPrefix(open) else { return nil }
        let content = text.dropFirst(open.count)
        guard let closeRange = content.range(of: close) else { return nil }
        return (String(content[..<closeRange.lowerBound]), content[closeRange.upperBound...])
    }

    /// `{{SUP}}…{{/SUP}}`-style regions pass through unescaped apart from their own
    /// placeholders, as their contents aren't rendered through the Markdown parser.
    private static func articleMarkerRegion(in text: Substring) -> (String, Substring)? {
        let tagName = text.dropFirst(2).prefix { $0.isUppercase }
        guard !tagName.isEmpty else { return nil }
        let open = "{{\(tagName)}}"
        let close = "{{/\(tagName)}}"
        guard let (content, rest) = enclosedText(in: text, open: open, close: close) else {
            return nil
        }
        return (open + Extractor.composeInlineFormatting(content, escapingLiterals: false) + close, rest)
    }
}
