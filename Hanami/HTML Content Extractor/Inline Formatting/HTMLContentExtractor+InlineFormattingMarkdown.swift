import Foundation

nonisolated extension HTMLContentExtractor {

    static let wordJoiner: Character = "\u{2060}"

    private enum InlineStyle: CaseIterable {
        case bold
        case italic

        var delimiter: String {
            switch self {
            case .bold: "**"
            case .italic: "*"
            }
        }
    }

    private enum MarkdownPiece {
        case character(Character)
        case delimiter(String, isOpening: Bool)
    }

    /// Links are emitted innermost and split per formatting run (`**[a](u)**[b](u)`),
    /// as adjacent links to the same URL render as one continuous link.
    static func markdown(from segments: [InlineFormattingSegment], escapingLiterals: Bool) -> String {
        var pieces: [MarkdownPiece] = []
        var openStyles: [InlineStyle] = []

        func closeStyles(downTo depth: Int) {
            while openStyles.count > depth, let style = openStyles.popLast() {
                pieces.append(.delimiter(style.delimiter, isOpening: false))
            }
        }

        for segment in segments {
            let wanted = InlineStyle.allCases.filter { style in
                style == .bold ? segment.isBold : segment.isItalic
            }
            if let firstUnwanted = openStyles.firstIndex(where: { !wanted.contains($0) }) {
                closeStyles(downTo: firstUnwanted)
            }
            for style in wanted where !openStyles.contains(style) {
                openStyles.append(style)
                pieces.append(.delimiter(style.delimiter, isOpening: true))
            }
            let text = markdownText(for: segment, escapingLiterals: escapingLiterals)
            pieces.append(contentsOf: text.map { .character($0) })
        }
        closeStyles(downTo: 0)

        return renderWithFlankingJoiners(movingSpacesOutsideDelimiters(pieces))
    }

    private static func markdownText(for segment: InlineFormattingSegment, escapingLiterals: Bool) -> String {
        switch segment.kind {
        case .marker:
            return segment.text
        case .codeSpan where segment.linkURL == nil:
            let fence = segment.text.contains("`") ? "``" : "`"
            let padding = segment.text.hasPrefix("`") || segment.text.hasSuffix("`") ? " " : ""
            return fence + padding + segment.text + padding + fence
        case .text, .codeSpan:
            let text = escapingLiterals ? segment.text.markdownEscaped : segment.text
            guard let linkURL = segment.linkURL else { return text }
            // Foundation drops code formatting inside link text, so code spans become plain link text.
            let linkText = text
                .replacingOccurrences(of: "[", with: "\\[")
                .replacingOccurrences(of: "]", with: "\\]")
            return "[\(linkText)](\(linkURL))"
        }
    }

    /// Styles reopened after a nested style closes can land in front of a space.
    private static func movingSpacesOutsideDelimiters(_ pieces: [MarkdownPiece]) -> [MarkdownPiece] {
        var pieces = pieces
        var didMove = true
        while didMove {
            didMove = false
            for index in pieces.indices.dropLast() {
                switch (pieces[index], pieces[index + 1]) {
                case (.delimiter(_, isOpening: true), .character(let character)) where isInlineSpace(character),
                     (.character(let character), .delimiter(_, isOpening: false)) where isInlineSpace(character):
                    pieces.swapAt(index, index + 1)
                    didMove = true
                default:
                    continue
                }
            }
        }
        return pieces
    }

    /// Delimiters touching punctuation (including `[` and `)` from links) only parse
    /// when the other side is whitespace or punctuation, which CJK text never is.
    /// A word joiner is neither, so slipping one in keeps the delimiter flanking.
    private static func renderWithFlankingJoiners(_ pieces: [MarkdownPiece]) -> String {
        var result = ""
        for (index, piece) in pieces.enumerated() {
            guard case .delimiter(let delimiter, let isOpening) = piece else {
                if case .character(let character) = piece {
                    result.append(character)
                }
                continue
            }
            let previous = index > 0 ? pieces[index - 1] : nil
            let next = index < pieces.count - 1 ? pieces[index + 1] : nil
            let previousCharacter = flankingCharacter(of: previous)
            let nextCharacter = flankingCharacter(of: next)
            if touchesAsterisk(previous) {
                result.append(wordJoiner)
            }
            if !isOpening, let previousCharacter, isMarkdownPunctuation(previousCharacter),
               let nextCharacter, !isWhitespaceOrPunctuation(nextCharacter) {
                result.append(wordJoiner)
            }
            result += delimiter
            if isOpening, let nextCharacter, isMarkdownPunctuation(nextCharacter),
               let previousCharacter, !isWhitespaceOrPunctuation(previousCharacter) {
                result.append(wordJoiner)
            } else if case .character("*") = next {
                result.append(wordJoiner)
            }
        }
        return result
    }

    private static func touchesAsterisk(_ piece: MarkdownPiece?) -> Bool {
        switch piece {
        case .delimiter: true
        case .character(let character): character == "*"
        case nil: false
        }
    }

    private static func flankingCharacter(of piece: MarkdownPiece?) -> Character? {
        switch piece {
        case .delimiter: wordJoiner
        case .character(let character): character == "*" ? wordJoiner : character
        case nil: nil
        }
    }

    private static func isWhitespaceOrPunctuation(_ character: Character) -> Bool {
        character.isWhitespace || isMarkdownPunctuation(character)
    }

    private static func isMarkdownPunctuation(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.properties.generalCategory {
        case .connectorPunctuation, .dashPunctuation, .openPunctuation, .closePunctuation,
             .initialPunctuation, .finalPunctuation, .otherPunctuation,
             .mathSymbol, .currencySymbol, .modifierSymbol, .otherSymbol:
            return true
        default:
            return false
        }
    }
}
