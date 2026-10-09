import Foundation

public nonisolated extension HTMLContentExtractor {

    /// Foundation's Markdown parser drops emphasis inside link text and only honours
    /// delimiters that are flanking, so bold/italic/link/code placeholders are rebuilt
    /// into Markdown that survives it instead of being substituted one-to-one.
    /// Literal Markdown characters in the text are escaped so they render as typed.
    static func composeInlineFormatting(_ text: String, escapingLiterals: Bool = true) -> String {
        let segments = InlineFormattingTokenizer.segments(from: text)
        return markdown(from: normalizeInlineWhitespace(in: segments), escapingLiterals: escapingLiterals)
    }
}
