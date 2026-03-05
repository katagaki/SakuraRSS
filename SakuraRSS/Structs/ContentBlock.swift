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
