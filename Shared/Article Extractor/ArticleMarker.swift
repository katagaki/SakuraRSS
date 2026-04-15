import Foundation

/// Marker token escaping shared between `ArticleExtractor` (which produces
/// `{{IMG}}`/`{{CODE}}`/`{{VIDEO}}`/etc. markers from HTML) and consumers
/// like `ContentBlock.parse` (which split on those markers).
///
/// If an article legitimately contains the literal sequence `{{IMG}}` —
/// e.g. a Mustache or Handlebars tutorial, templating documentation — it
/// must be escaped before being emitted as paragraph text, otherwise
/// downstream parsers will misinterpret it as an extractor marker and
/// corrupt the rendered output.
///
/// Lives in its own file (rather than as an extension on `ArticleExtractor`)
/// because some targets (Add Feed, WidgetsExtension) compile
/// `RedditPostScraper` — a producer of marker strings — but exclude
/// `ArticleExtractor.swift` due to its SwiftSoup dependency. This helper
/// has no dependencies beyond Foundation and is therefore safe to include
/// everywhere.
nonisolated enum ArticleMarker {

    /// All marker tokens emitted by the extractor and friends. The escaped
    /// form uses U+E000 / U+E001 from the Unicode Private Use Area as
    /// delimiters: those characters cannot occur in real article text, and
    /// crucially the escaped form does not contain the original `{{TOKEN}}`
    /// substring, so callers checking `text.contains("{{IMG}}")` won't get
    /// false positives from escaped literals.
    private static let table: [(literal: String, escaped: String)] = [
        ("{{IMG}}",      "\u{E000}IMG\u{E001}"),
        ("{{/IMG}}",     "\u{E000}/IMG\u{E001}"),
        ("{{IMGLINK}}",  "\u{E000}IMGLINK\u{E001}"),
        ("{{/IMGLINK}}", "\u{E000}/IMGLINK\u{E001}"),
        ("{{CODE}}",     "\u{E000}CODE\u{E001}"),
        ("{{/CODE}}",    "\u{E000}/CODE\u{E001}"),
        ("{{VIDEO}}",    "\u{E000}VIDEO\u{E001}"),
        ("{{/VIDEO}}",   "\u{E000}/VIDEO\u{E001}"),
        ("{{SUP}}",      "\u{E000}SUP\u{E001}"),
        ("{{/SUP}}",     "\u{E000}/SUP\u{E001}"),
        ("{{SUB}}",      "\u{E000}SUB\u{E001}"),
        ("{{/SUB}}",     "\u{E000}/SUB\u{E001}")
    ]

    /// Escapes literal marker sequences in `text` so they don't collide
    /// with markers injected by the extractor. Call `unescape(_:)` at every
    /// rendering or text-export boundary to reverse this.
    static func escape(_ text: String) -> String {
        guard text.contains("{{") else { return text }
        var result = text
        for (literal, escaped) in table where result.contains(literal) {
            result = result.replacingOccurrences(of: literal, with: escaped)
        }
        return result
    }

    /// Reverses `escape(_:)`. Safe to call on any string — strings without
    /// escape characters return unchanged.
    static func unescape(_ text: String) -> String {
        guard text.contains("\u{E000}") else { return text }
        var result = text
        for (literal, escaped) in table where result.contains(escaped) {
            result = result.replacingOccurrences(of: escaped, with: literal)
        }
        return result
    }
}
