import Foundation

public nonisolated extension HTMLContentExtractor {

    /// Cuts the tail after the last prose paragraph from its first link-dense
    /// block (tag lists, "Latest in…" cards, follow/deal links), along with
    /// any orphan labels such as "Topics" leading into it.
    static func removeLinkDenseTail(_ paragraphs: [String]) -> [String] {
        guard let lastProseIndex = paragraphs.lastIndex(where: isProseParagraph),
              var cutIndex = paragraphs[(lastProseIndex + 1)...].firstIndex(where: isLinkDenseParagraph)
        else { return paragraphs }
        while cutIndex > lastProseIndex + 1, isOrphanLabel(paragraphs[cutIndex - 1]) {
            cutIndex -= 1
        }
        return Array(paragraphs[..<cutIndex])
    }

    private static let markdownLinkRegex = try? NSRegularExpression(
        pattern: #"\[((?:[^\]\\]|\\.)*)\]\([^)\s]*\)"#
    )

    private static func isProseParagraph(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("#"), !trimmed.hasPrefix("{{") else { return false }
        let (visibleLength, linkLength) = visibleAndLinkTextLength(of: trimmed)
        return visibleLength >= 80 && linkLength * 2 < visibleLength
    }

    private static func isLinkDenseParagraph(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.hasPrefix("{{") else { return false }
        let (visibleLength, linkLength) = visibleAndLinkTextLength(of: trimmed)
        guard visibleLength > 0 else { return false }
        let isShortAndMostlyLinks = visibleLength < 120 && linkLength * 2 >= visibleLength
        let isNearlyAllLinks = linkLength * 5 >= visibleLength * 4
        return isShortAndMostlyLinks || isNearlyAllLinks
    }

    private static func isOrphanLabel(_ paragraph: String) -> Bool {
        let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { return true }
        guard trimmed.count < 40, let lastCharacter = trimmed.last else { return false }
        return !".!?。！？\"”」)".contains(lastCharacter)
    }

    private static func visibleAndLinkTextLength(of paragraph: String) -> (visible: Int, link: Int) {
        guard let markdownLinkRegex else { return (paragraph.count, 0) }
        let nsParagraph = paragraph as NSString
        let matches = markdownLinkRegex.matches(
            in: paragraph, range: NSRange(location: 0, length: nsParagraph.length)
        )
        var linkLength = 0
        var markupLength = 0
        for match in matches {
            let linkText = nsParagraph.substring(with: match.range(at: 1))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            linkLength += linkText.count
            markupLength += nsParagraph.substring(with: match.range).count - linkText.count
        }
        let visibleText = paragraph.filter { !$0.isWhitespace }
        let visibleLength = max(visibleText.count - markupLength, 0)
        return (visibleLength, min(linkLength, visibleLength))
    }
}
