import Foundation

nonisolated extension HTMLContentExtractor {

    /// Moves whitespace at the edges of a formatted run outside its delimiters,
    /// since `**Bold **` and `[ link](url)` don't parse as intended.
    static func normalizeInlineWhitespace(in segments: [InlineFormattingSegment]) -> [InlineFormattingSegment] {
        let merged = mergeAdjacentSegments(segments)
        var result: [InlineFormattingSegment] = []
        for (index, segment) in merged.enumerated() {
            let previous = index > 0 ? merged[index - 1] : nil
            let next = index < merged.count - 1 ? merged[index + 1] : nil
            guard segment.kind == .text else {
                result.append(segment)
                continue
            }
            let leading = String(segment.text.prefix(while: isInlineSpace))
            guard leading.count < segment.text.count else {
                result.append(segment.sharedFormatting(with: previous, text: segment.text)
                    .sharedFormatting(with: next, text: segment.text))
                continue
            }
            let trailing = String(segment.text.reversed().prefix(while: isInlineSpace).reversed())
            if !leading.isEmpty {
                result.append(segment.sharedFormatting(with: previous, text: leading))
            }
            var trimmed = segment
            trimmed.text = String(segment.text.dropFirst(leading.count).dropLast(trailing.count))
            result.append(trimmed)
            if !trailing.isEmpty {
                result.append(segment.sharedFormatting(with: next, text: trailing))
            }
        }
        return mergeAdjacentSegments(result)
    }

    static func isInlineSpace(_ character: Character) -> Bool {
        character.isWhitespace && character != "\n"
    }

    private static func mergeAdjacentSegments(_ segments: [InlineFormattingSegment]) -> [InlineFormattingSegment] {
        var result: [InlineFormattingSegment] = []
        for segment in segments where !segment.text.isEmpty {
            if let last = result.last, last.canMerge(with: segment) {
                result[result.count - 1].text += segment.text
            } else {
                result.append(segment)
            }
        }
        return result
    }
}
