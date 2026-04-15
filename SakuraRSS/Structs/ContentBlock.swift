import Foundation

enum ContentBlock: Identifiable {
    case text(String)
    case image(URL, link: URL? = nil)
    case code(String)
    case video(URL)

    var id: String {
        switch self {
        case .text(let text): return "text-\(text.hashValue)"
        case .image(let url, _): return "image-\(url.absoluteString)"
        case .code(let text): return "code-\(text.hashValue)"
        case .video(let url): return "video-\(url.absoluteString)"
        }
    }

    /// Strips image and code markers from text, returning plain text suitable for translation/summarization.
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
        .replacingOccurrences(of: "{{CODE}}", with: "")
        .replacingOccurrences(of: "{{/CODE}}", with: "")
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        return ArticleMarker.unescape(stripped)
    }

    /// Strips Markdown formatting from text, returning plain text suitable for content previews.
    /// Handles links (including escaped brackets), bold, italic, headings, and sup/sub markers.
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Strip image markers (including optional link markers)
        result = result.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{IMGLINK\}\}.+?\{\{/IMGLINK\}\}"#, with: "", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{VIDEO\}\}.+?\{\{/VIDEO\}\}"#, with: "", options: .regularExpression
        )
        // Strip code markers, keeping content
        result = result.replacingOccurrences(of: "{{CODE}}", with: "")
        result = result.replacingOccurrences(of: "{{/CODE}}", with: "")
        // Strip sup/sub markers, keeping content
        result = result.replacingOccurrences(
            of: #"\{\{SUP\}\}(.+?)\{\{/SUP\}\}"#, with: "$1", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\{\{SUB\}\}(.+?)\{\{/SUB\}\}"#, with: "$1", options: .regularExpression
        )
        // Strip Markdown links [text](url) → text (handle escaped brackets)
        result = result.replacingOccurrences(
            of: #"\[((?:[^\]\\]|\\.)+)\]\([^)]+\)"#, with: "$1", options: .regularExpression
        )
        // Unescape brackets
        result = result.replacingOccurrences(of: "\\[", with: "[")
        result = result.replacingOccurrences(of: "\\]", with: "]")
        // Strip bold **text** → text
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression
        )
        // Strip italic *text* → text
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression
        )
        // Strip heading prefixes
        result = result.replacingOccurrences(
            of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression
        )
        // Collapse whitespace
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )
        result = ArticleMarker.unescape(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> [ContentBlock] {
        let pattern = #"\{\{(IMG|CODE|VIDEO)\}\}(.*?)\{\{/(IMG|CODE|VIDEO)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return [.text(ArticleMarker.unescape(text))]
        }

        let linkPattern = #"^(.+?)\{\{IMGLINK\}\}(.+?)\{\{/IMGLINK\}\}$"#
        let linkRegex = try? NSRegularExpression(pattern: linkPattern)

        var blocks: [ContentBlock] = []
        var lastEnd = 0

        for match in matches {
            // Text before the marker
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

            if tag == "CODE" {
                if !content.isEmpty {
                    blocks.append(.code(ArticleMarker.unescape(content)))
                }
            } else if tag == "VIDEO" {
                if let url = URL(string: content) {
                    blocks.append(.video(url))
                }
            } else {
                // IMG — possibly with a link
                let nsContent = content as NSString
                if let linkRegex,
                   let linkMatch = linkRegex.firstMatch(
                    in: content, range: NSRange(location: 0, length: nsContent.length)
                   ) {
                    let imgURLString = nsContent.substring(with: linkMatch.range(at: 1))
                    let linkURLString = nsContent.substring(with: linkMatch.range(at: 2))
                    if let imgURL = URL(string: imgURLString) {
                        blocks.append(.image(imgURL, link: URL(string: linkURLString)))
                    }
                } else if let url = URL(string: content) {
                    blocks.append(.image(url))
                }
            }

            lastEnd = match.range.location + match.range.length
        }

        // Text after the last marker
        if lastEnd < nsText.length {
            let after = nsText.substring(from: lastEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                blocks.append(.text(ArticleMarker.unescape(after)))
            }
        }

        return blocks
    }
}
