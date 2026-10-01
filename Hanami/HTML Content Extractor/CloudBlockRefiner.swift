import Foundation

/// Asks SakuraCloud whether the short and trailing paragraphs the extractor kept belong to the
/// content, and drops the ones it is confident do not. Any failure keeps the text as it was.
public nonisolated enum CloudBlockRefiner {

    static let dropBelowProbability = 0.15
    static let shortBlockLength = 280
    static let trailingBlockCount = 4
    static let mostCandidates = 120
    static let mostBlocks = 400
    static let longestBlock = 4000
    static let mostCharacters = 60_000
    static let mostDroppedShare = 0.4

    private static let markerRegex = try? NSRegularExpression(
        pattern: #"\{\{(IMG|CODE|VIDEO|AUDIO|YOUTUBE|XPOST|EMBED|TABLE|DL|MATH)\}\}.*?\{\{/\1\}\}"#,
        options: .dotMatchesLineSeparators
    )

    enum Piece: Equatable {
        case marker(String, kind: String)
        case text(String)
    }

    public static func refine(_ text: String, title: String, url: URL?) async -> String {
        guard SakuraCloud.isConfigured else { return text }
        let pieces = pieces(of: text)
        let candidates = candidateIndexes(in: pieces)
        guard !candidates.isEmpty else { return text }
        let blocks = pieces.map(cloudBlock)
        guard blocks.count <= mostBlocks,
              blocks.reduce(0, { $0 + $1.count }) <= mostCharacters else {
            log("CloudRefine", "Skipped: \(blocks.count) blocks are too many to send")
            return text
        }
        do {
            let probabilities = try await SakuraCloud.shared.classify(
                title: title, site: url?.host() ?? "", blocks: blocks, candidates: candidates
            )
            let dropped = Set(zip(candidates, probabilities)
                .filter { $0.1 < dropBelowProbability }
                .map(\.0))
            return refined(text, pieces: pieces, dropping: dropped)
        } catch {
            log("CloudRefine", "Kept rules-only text: \(error)")
            return text
        }
    }

    static func refined(_ text: String, pieces: [Piece], dropping dropped: Set<Int>) -> String {
        guard !dropped.isEmpty else { return text }
        let textLength = pieces.reduce(0) { total, piece in
            if case .text(let paragraph) = piece { return total + paragraph.count }
            return total
        }
        let droppedLength = dropped.reduce(0) { total, index in
            if case .text(let paragraph) = pieces[index] { return total + paragraph.count }
            return total
        }
        guard Double(droppedLength) <= Double(textLength) * mostDroppedShare else {
            log("CloudRefine", "Kept text: dropping \(dropped.count) blocks would remove too much")
            return text
        }
        for index in dropped.sorted() {
            if case .text(let paragraph) = pieces[index] {
                log("CloudRefine", "Dropped: \(paragraph.prefix(80))")
            }
        }
        return pieces.enumerated()
            .filter { !dropped.contains($0.offset) }
            .map { _, piece in
                switch piece {
                case .marker(let raw, _): raw
                case .text(let paragraph): paragraph
                }
            }
            .joined(separator: "\n\n")
    }

    static func pieces(of text: String) -> [Piece] {
        let nsText = text as NSString
        let matches = markerRegex?.matches(in: text, range: NSRange(location: 0, length: nsText.length)) ?? []
        var pieces: [Piece] = []
        var cursor = 0
        for match in matches {
            let gap = NSRange(location: cursor, length: match.range.location - cursor)
            pieces += paragraphs(in: nsText.substring(with: gap))
            let kind = nsText.substring(with: match.range(at: 1))
            pieces.append(.marker(nsText.substring(with: match.range), kind: kind))
            cursor = match.range.location + match.range.length
        }
        pieces += paragraphs(in: nsText.substring(from: cursor))
        return pieces
    }

    private static func paragraphs(in text: String) -> [Piece] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { .text($0) }
    }

    static func candidateIndexes(in pieces: [Piece]) -> [Int] {
        let textIndexes = pieces.indices.filter { index in
            if case .text = pieces[index] { return true }
            return false
        }
        let trailing = Set(textIndexes.suffix(trailingBlockCount))
        let candidates = textIndexes.filter { index in
            guard case .text(let paragraph) = pieces[index] else { return false }
            return paragraph.count < shortBlockLength || trailing.contains(index)
        }
        return Array(candidates.prefix(mostCandidates))
    }

    private static func cloudBlock(_ piece: Piece) -> String {
        switch piece {
        case .marker(_, let kind): "[\(kind.lowercased())]"
        case .text(let paragraph): String(ArticleMarker.unescape(paragraph).prefix(longestBlock))
        }
    }
}
