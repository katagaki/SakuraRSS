import Foundation

public extension HTMLContentExtractor {

    static let codeSpanOpenMarker = "{{CODE}}"
    static let codeSpanCloseMarker = "{{/CODE}}"

    /// Applies `transform` only to the spans outside `{{CODE}}…{{/CODE}}`, so
    /// code keeps its indentation and its tag-like text verbatim.
    static func mapOutsideCodeSpans(
        in text: String,
        transform: (String) -> String
    ) -> String {
        guard text.contains(codeSpanOpenMarker) else { return transform(text) }
        var result = ""
        var remaining = text[text.startIndex...]
        while let openRange = remaining.range(of: codeSpanOpenMarker) {
            result += transform(String(remaining[remaining.startIndex..<openRange.lowerBound]))
            let afterOpen = remaining[openRange.upperBound...]
            guard let closeRange = afterOpen.range(of: codeSpanCloseMarker) else {
                result += codeSpanOpenMarker
                remaining = afterOpen
                break
            }
            result += codeSpanOpenMarker
            result += afterOpen[afterOpen.startIndex..<closeRange.lowerBound]
            result += codeSpanCloseMarker
            remaining = afterOpen[closeRange.upperBound...]
        }
        result += transform(String(remaining))
        return result
    }
}
