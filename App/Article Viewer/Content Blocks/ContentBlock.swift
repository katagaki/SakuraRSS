import Foundation
import Hanami

enum ContentBlock: Identifiable {
    case text(String)
    case image(URL, link: URL? = nil)
    case code(String)
    case video(URL)
    case audio(URL)
    case youtube(String)
    case xPost(URL)
    case embed(EmbedProvider, URL)
    case table(header: [String], rows: [[String]])
    case definitionList(items: [DefinitionListItem])
    case math(String)

    nonisolated struct DefinitionListItem: Hashable, Sendable {
        let term: String
        let definitions: [String]
    }

    nonisolated var id: String {
        switch self {
        case .text(let text): return "text-\(text.hashValue)"
        case .image(let url, _): return "image-\(url.absoluteString)"
        case .code(let text): return "code-\(text.hashValue)"
        case .video(let url): return "video-\(url.absoluteString)"
        case .audio(let url): return "audio-\(url.absoluteString)"
        case .youtube(let videoID): return "youtube-\(videoID)"
        case .xPost(let url): return "xpost-\(url.absoluteString)"
        case .embed(let provider, let url):
            return "embed-\(provider.rawValue)-\(url.absoluteString)"
        case .table(let header, let rows):
            return "table-\(header.hashValue)-\(rows.count)"
        case .definitionList(let items):
            return "dl-\(items.hashValue)"
        case .math(let latex): return "math-\(latex.hashValue)"
        }
    }

    /// Strips block markers, returning plain text suitable for translation/summarization.
    nonisolated static func plainText(from text: String) -> String {
        let stripped = text.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{AUDIO\}\}.+?\{\{/AUDIO\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{YOUTUBE\}\}.+?\{\{/YOUTUBE\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{XPOST\}\}.+?\{\{/XPOST\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{EMBED\}\}.+?\{\{/EMBED\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"(?s)\{\{TABLE\}\}.+?\{\{/TABLE\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"(?s)\{\{DL\}\}.+?\{\{/DL\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\{\{MATH\}\}.+?\{\{/MATH\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(of: "{{CODE}}", with: "")
        .replacingOccurrences(of: "{{/CODE}}", with: "")
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return ArticleMarker.unescape(stripped)
    }

    /// Strips Markdown formatting, returning plain text for content previews.
    nonisolated static func stripMarkdown(_ text: String) -> String {
        var result = text
        for pattern in markdownStripPatterns {
            result = result.replacingOccurrences(
                of: pattern.pattern, with: pattern.replacement, options: .regularExpression
            )
        }
        result = result.replacingOccurrences(of: "{{CODE}}", with: "")
        result = result.replacingOccurrences(of: "{{/CODE}}", with: "")
        result = result.replacingOccurrences(of: "\\[", with: "[")
        result = result.replacingOccurrences(of: "\\]", with: "]")
        result = ArticleMarker.unescape(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static let markdownStripPatterns: [(pattern: String, replacement: String)] = [
        (#"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, ""),
        (#"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, ""),
        (#"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, ""),
        (#"\{\{AUDIO\}\}.+?\{\{/AUDIO\}\}"#, ""),
        (#"\{\{YOUTUBE\}\}.+?\{\{/YOUTUBE\}\}"#, ""),
        (#"\{\{XPOST\}\}.+?\{\{/XPOST\}\}"#, ""),
        (#"\{\{EMBED\}\}.+?\{\{/EMBED\}\}"#, ""),
        (#"(?s)\{\{TABLE\}\}.+?\{\{/TABLE\}\}"#, ""),
        (#"(?s)\{\{DL\}\}.+?\{\{/DL\}\}"#, ""),
        (#"\{\{MATH\}\}(.+?)\{\{/MATH\}\}"#, "$1"),
        (#"\{\{SUP\}\}(.+?)\{\{/SUP\}\}"#, "$1"),
        (#"\{\{SUB\}\}(.+?)\{\{/SUB\}\}"#, "$1"),
        (#"\[((?:[^\]\\]|\\.)+)\]\([^)]+\)"#, "$1"),
        (#"\*\*(.+?)\*\*"#, "$1"),
        (#"\*(.+?)\*"#, "$1"),
        (#"(?m)^#{1,6}\s+"#, ""),
        (#"\n{3,}"#, "\n\n")
    ]

    nonisolated private static let blockRegex = try? NSRegularExpression(
        pattern: #"\{\{(IMG|CODE|VIDEO|AUDIO|YOUTUBE|XPOST|EMBED|TABLE|DL|MATH)\}\}(.*?)\{\{/\1\}\}"#,
        options: .dotMatchesLineSeparators
    )

    nonisolated private static let imageLinkRegex = try? NSRegularExpression(
        pattern: #"^(.+?)\{\{IMGLINK\}\}(.+?)\{\{/IMGLINK\}\}$"#
    )

    nonisolated static func parse(_ text: String) -> [ContentBlock] {
        guard let regex = blockRegex else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let (nsText, matches) = ArticleMarker.regexMatches(of: regex, in: text)

        guard !matches.isEmpty else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let linkRegex = imageLinkRegex

        var blocks: [ContentBlock] = []
        var lastEnd = 0

        for match in matches {
            if match.range.location > lastEnd {
                let before = nsText.substring(
                    with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty {
                    blocks.append(.text(ArticleMarker.unescape(before)))
                }
            }

            let tag = nsText.substring(with: match.range(at: 1))
            let content = nsText.substring(with: match.range(at: 2))
            if let block = block(forTag: tag, content: content, linkRegex: linkRegex) {
                blocks.append(block)
            }

            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsText.length {
            let after = nsText.substring(from: lastEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                blocks.append(.text(ArticleMarker.unescape(after)))
            }
        }

        return blocks
    }

    nonisolated private static func block(
        forTag tag: String,
        content: String,
        linkRegex: NSRegularExpression?
    ) -> ContentBlock? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        switch tag {
        case "CODE":
            return content.isEmpty ? nil : .code(ArticleMarker.unescape(content))
        case "VIDEO", "AUDIO", "YOUTUBE", "XPOST":
            return urlBlock(forTag: tag, content: trimmed)
        case "EMBED":
            let parts = trimmed.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let provider = EmbedProvider(markerValue: String(parts[0])),
                  let url = URL(string: String(parts[1])) else { return nil }
            return .embed(provider, url)
        case "TABLE":
            return parseTableMarker(content)
        case "DL":
            return parseDefinitionListMarker(content)
        case "MATH":
            return trimmed.isEmpty ? nil : .math(ArticleMarker.unescape(trimmed))
        default:
            return imageBlock(content: content, linkRegex: linkRegex)
        }
    }

    nonisolated private static func urlBlock(forTag tag: String, content: String) -> ContentBlock? {
        switch tag {
        case "VIDEO": return URL(string: content).map { .video($0) }
        case "AUDIO": return URL(string: content).map { .audio($0) }
        case "YOUTUBE": return content.isEmpty ? nil : .youtube(content)
        case "XPOST": return URL(string: content).map { .xPost($0) }
        default: return nil
        }
    }

    nonisolated private static func imageBlock(content: String, linkRegex: NSRegularExpression?) -> ContentBlock? {
        let nsContent = content as NSString
        if let linkRegex,
           let linkMatch = linkRegex.firstMatch(
            in: content, range: NSRange(location: 0, length: nsContent.length)
           ) {
            let imgURLString = nsContent.substring(with: linkMatch.range(at: 1))
            let linkURLString = nsContent.substring(with: linkMatch.range(at: 2))
            return URL(string: imgURLString).map { .image($0, link: URL(string: linkURLString)) }
        }
        return URL(string: content).map { .image($0) }
    }

    /// Parses `{{TABLE}}` payload `header1|header2\nrow1col1|row1col2\n…` into header + rows.
    nonisolated private static func parseTableMarker(_ content: String) -> ContentBlock? {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        guard !lines.isEmpty else { return nil }
        let parseRow: (String) -> [String] = { line in
            line.components(separatedBy: "|").map {
                ArticleMarker.unescape(
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "¦", with: "|")
                )
            }
        }
        let header = parseRow(lines[0])
        let rows = lines.dropFirst()
            .map(parseRow)
            .filter { !$0.allSatisfy(\.isEmpty) }
        guard !header.isEmpty else { return nil }
        return .table(header: header, rows: rows)
    }

    /// Parses `{{DL}}` payload `term1|def1a|def1b\nterm2|def2a…` into definition items.
    /// The first cell on each line is the term; remaining cells are its definitions.
    nonisolated private static func parseDefinitionListMarker(_ content: String) -> ContentBlock? {
        let lines = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }
        let items: [DefinitionListItem] = lines.compactMap { line in
            let cells = line.components(separatedBy: "|").map {
                ArticleMarker.unescape(
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "¦", with: "|")
                )
            }
            guard let term = cells.first, !term.isEmpty else { return nil }
            let definitions = Array(cells.dropFirst()).filter { !$0.isEmpty }
            return DefinitionListItem(term: term, definitions: definitions)
        }
        guard !items.isEmpty else { return nil }
        return .definitionList(items: items)
    }
}
