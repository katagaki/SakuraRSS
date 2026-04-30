import Foundation

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
    case math(String)

    var id: String {
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
        case .math(let latex): return "math-\(latex.hashValue)"
        }
    }

    /// Strips block markers, returning plain text suitable for translation/summarization.
    static func plainText(from text: String) -> String {
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
            of: #"\{\{MATH\}\}.+?\{\{/MATH\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(of: "{{CODE}}", with: "")
        .replacingOccurrences(of: "{{/CODE}}", with: "")
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return ArticleMarker.unescape(stripped)
    }

    /// Strips Markdown formatting, returning plain text for content previews.
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{AUDIO\}\}.+?\{\{/AUDIO\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{YOUTUBE\}\}.+?\{\{/YOUTUBE\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{XPOST\}\}.+?\{\{/XPOST\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{EMBED\}\}.+?\{\{/EMBED\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?s)\{\{TABLE\}\}.+?\{\{/TABLE\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{MATH\}\}(.+?)\{\{/MATH\}\}"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(of: "{{CODE}}", with: "")
        result = result.replacingOccurrences(of: "{{/CODE}}", with: "")
        result = result.replacingOccurrences(
            of: #"\{\{SUP\}\}(.+?)\{\{/SUP\}\}"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{SUB\}\}(.+?)\{\{/SUB\}\}"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\[((?:[^\]\\]|\\.)+)\]\([^)]+\)"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(of: "\\[", with: "[")
        result = result.replacingOccurrences(of: "\\]", with: "]")
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )
        result = ArticleMarker.unescape(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> [ContentBlock] {
        // swiftlint:disable:next line_length
        let pattern = #"\{\{(IMG|CODE|VIDEO|AUDIO|YOUTUBE|XPOST|EMBED|TABLE|MATH)\}\}(.*?)\{\{/(IMG|CODE|VIDEO|AUDIO|YOUTUBE|XPOST|EMBED|TABLE|MATH)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let (nsText, matches) = ArticleMarker.regexMatches(of: regex, in: text)

        guard !matches.isEmpty else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let linkPattern = #"^(.+?)\{\{IMGLINK\}\}(.+?)\{\{/IMGLINK\}\}$"#
        let linkRegex = try? NSRegularExpression(pattern: linkPattern)

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

    private static func block(
        forTag tag: String,
        content: String,
        linkRegex: NSRegularExpression?
    ) -> ContentBlock? {
        switch tag {
        case "CODE":
            return content.isEmpty ? nil : .code(ArticleMarker.unescape(content))
        case "VIDEO":
            return URL(string: content).map { .video($0) }
        case "AUDIO":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: trimmed).map { .audio($0) }
        case "YOUTUBE":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .youtube(trimmed)
        case "XPOST":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: trimmed).map { .xPost($0) }
        case "EMBED":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = trimmed.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let provider = EmbedProvider(markerValue: String(parts[0])),
                  let url = URL(string: String(parts[1])) else { return nil }
            return .embed(provider, url)
        case "TABLE":
            return parseTableMarker(content)
        case "MATH":
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : .math(ArticleMarker.unescape(trimmed))
        default:
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
    }

    /// Parses `{{TABLE}}` payload `header1|header2\nrow1col1|row1col2\n…` into header + rows.
    private static func parseTableMarker(_ content: String) -> ContentBlock? {
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
}
