import Foundation

enum ContentBlock: Identifiable {
    case text(String)
    case image(URL)

    var id: String {
        switch self {
        case .text(let text): return "text-\(text.hashValue)"
        case .image(let url): return "image-\(url.absoluteString)"
        }
    }

    /// Strips image markers from text, returning plain text suitable for translation/summarization.
    static func plainText(from text: String) -> String {
        text.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
        .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Strips Markdown formatting from text, returning plain text suitable for content previews.
    /// Handles links (including escaped brackets), bold, italic, headings, and sup/sub markers.
    static func stripMarkdown(_ text: String) -> String {
        var result = text
        // Strip image markers
        result = result.replacingOccurrences(
            of: #"\{\{IMG\}\}.+?\{\{/IMG\}\}"#, with: "", options: .regularExpression
        )
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
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(_ text: String) -> [ContentBlock] {
        let pattern = #"\{\{IMG\}\}(.+?)\{\{/IMG\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(text)]
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard !matches.isEmpty else {
            return [.text(text)]
        }

        var blocks: [ContentBlock] = []
        var lastEnd = 0

        for match in matches {
            // Text before the image
            if match.range.location > lastEnd {
                let before = nsText.substring(
                    with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty {
                    blocks.append(.text(before))
                }
            }

            // The image
            let urlString = nsText.substring(with: match.range(at: 1))
            if let url = URL(string: urlString) {
                blocks.append(.image(url))
            }

            lastEnd = match.range.location + match.range.length
        }

        // Text after the last image
        if lastEnd < nsText.length {
            let after = nsText.substring(from: lastEnd)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !after.isEmpty {
                blocks.append(.text(after))
            }
        }

        return blocks
    }
}
