import Foundation

nonisolated struct InlineFormattingSegment: Equatable {

    enum Kind: Equatable {
        case text
        case codeSpan
        case marker
    }

    var text: String
    var kind: Kind = .text
    var isBold: Bool
    var isItalic: Bool
    var linkURL: String?

    static func plain(_ text: String) -> InlineFormattingSegment {
        InlineFormattingSegment(text: text, isBold: false, isItalic: false, linkURL: nil)
    }

    static func marker(_ text: String) -> InlineFormattingSegment {
        InlineFormattingSegment(text: text, kind: .marker, isBold: false, isItalic: false, linkURL: nil)
    }

    func canMerge(with other: InlineFormattingSegment) -> Bool {
        kind == .text && other.kind == .text
            && isBold == other.isBold && isItalic == other.isItalic && linkURL == other.linkURL
    }

    func sharedFormatting(with other: InlineFormattingSegment?, text: String) -> InlineFormattingSegment {
        guard let other else { return .plain(text) }
        return InlineFormattingSegment(
            text: text,
            isBold: isBold && other.isBold,
            isItalic: isItalic && other.isItalic,
            linkURL: linkURL == other.linkURL ? linkURL : nil
        )
    }
}
