import CoreText
import Foundation

public nonisolated extension NSMutableAttributedString {

    /// Replaces ruby markers with their base text annotated by the reading.
    /// Returns whether any ruby was applied.
    @discardableResult
    func applyRubyAnnotations() -> Bool {
        guard RubyMarkup.containsRuby(string), let regex = RubyMarkup.markerRegex else { return false }
        let matches = regex.matches(
            in: string, range: NSRange(location: 0, length: length)
        )
        for match in matches.reversed() {
            let reading = (string as NSString).substring(with: match.range(at: 2))
            let base = NSMutableAttributedString(attributedString: attributedSubstring(from: match.range(at: 1)))
            let annotation = CTRubyAnnotationCreateWithAttributes(
                .auto, .auto, .before, reading as CFString, [:] as CFDictionary
            )
            base.addAttribute(
                NSAttributedString.Key(kCTRubyAnnotationAttributeName as String),
                value: annotation,
                range: NSRange(location: 0, length: base.length)
            )
            replaceCharacters(in: match.range, with: base)
        }
        return !matches.isEmpty
    }
}
