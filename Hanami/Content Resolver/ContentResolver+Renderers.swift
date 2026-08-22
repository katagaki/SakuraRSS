import Foundation

public extension ContentResolver {

    /// Builds the article body for an Instagram post: every carousel image
    /// stacked above the caption. Falls back to `article.imageURL` when the
    /// post is single-image (carousel array is empty in that case).
    func renderInstagramPostContent() -> String {
        let imageURLs = !article.carouselImageURLs.isEmpty
            ? article.carouselImageURLs
            : (article.imageURL.map { [$0] } ?? [])

        var sections: [String] = imageURLs.map { "{{IMG}}\($0){{/IMG}}" }
        let caption = (article.summary ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            sections.append(ArticleMarker.escape(caption))
        }
        return sections.joined(separator: "\n\n")
    }

    func renderXTweetContent(_ content: ParsedTweetContent) -> String {
        var sections: [String] = []
        for item in content.threadItems {
            var section = ArticleMarker.escape(Self.linkifyBareURLs(in: item.text))
            for imageURL in item.imageURLs {
                section += "\n\n{{IMG}}\(imageURL){{/IMG}}"
            }
            if let videoURL = item.videoURL {
                section += "\n\n" + Self.videoMarker(
                    url: videoURL,
                    aspectRatio: item.videoAspectRatio,
                    isGIF: item.videoIsGIF
                )
            }
            if let quoted = item.quotedTweetURL {
                section += "\n\n{{XPOST}}\(quoted){{/XPOST}}"
            }
            sections.append(section)
        }
        return sections.joined(separator: "\n\n")
    }

    /// Builds a `{{VIDEO}}` marker with the extended `url|aspectRatio|gif`
    /// payload understood by the article viewer's block parser.
    static func videoMarker(url: String, aspectRatio: Double?, isGIF: Bool) -> String {
        var payload = url
        if let aspectRatio {
            payload += "|\(String(format: "%.4f", aspectRatio))"
            if isGIF {
                payload += "|gif"
            }
        } else if isGIF {
            payload += "||gif"
        }
        return "{{VIDEO}}\(payload){{/VIDEO}}"
    }

    /// Wraps bare `http(s)` URLs in Markdown links with an X-style shortened
    /// display text so they render tappable in the article viewer. The
    /// character class is ASCII-only so URLs pasted flush against CJK text
    /// (common in Japanese posts) don't swallow the following words.
    static func linkifyBareURLs(in text: String) -> String {
        guard text.contains("http"), let regex = bareURLRegex else { return text }
        let nsText = text as NSString
        let matches = regex.matches(
            in: text, range: NSRange(location: 0, length: nsText.length)
        )
        guard !matches.isEmpty else { return text }

        var result = ""
        var lastEnd = 0
        for match in matches {
            result += nsText.substring(
                with: NSRange(location: lastEnd, length: match.range.location - lastEnd)
            )
            let urlString = trimmedTrailingPunctuation(
                in: nsText.substring(with: match.range)
            )
            // Trimmed characters are ASCII, so character count matches the
            // UTF-16 offsets used by NSRange.
            let trimmedCount = nsText.substring(with: match.range).count
                - urlString.count
            result += markdownLink(for: urlString)
            lastEnd = match.range.location + match.range.length - trimmedCount
        }
        result += nsText.substring(from: lastEnd)
        return result
    }

    private static let bareURLRegex = try? NSRegularExpression(
        pattern: #"https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+"#
    )

    /// Drops trailing sentence punctuation, but keeps a closing bracket that
    /// the URL itself opened, as in `…/Mercury_(planet)`.
    private static func trimmedTrailingPunctuation(in urlString: String) -> String {
        var result = urlString
        while let last = result.last {
            if ".,;:!?'\"".contains(last) {
                result.removeLast()
                continue
            }
            if last == ")", !isBracketBalanced(result, open: "(", close: ")") {
                result.removeLast()
                continue
            }
            if last == "]", !isBracketBalanced(result, open: "[", close: "]") {
                result.removeLast()
                continue
            }
            break
        }
        return result
    }

    private static func isBracketBalanced(
        _ text: String, open: Character, close: Character
    ) -> Bool {
        var depth = 0
        for character in text {
            if character == open {
                depth += 1
            } else if character == close {
                depth -= 1
                if depth < 0 { return false }
            }
        }
        return depth == 0
    }

    private static func markdownLink(for urlString: String) -> String {
        var display = urlString
        if display.hasPrefix("https://") {
            display = String(display.dropFirst(8))
        } else if display.hasPrefix("http://") {
            display = String(display.dropFirst(7))
        }
        if display.hasPrefix("www.") {
            display = String(display.dropFirst(4))
        }
        while display.hasSuffix("/") {
            display = String(display.dropLast())
        }
        if display.count > 40 {
            display = display.prefix(40) + "…"
        }
        display = display
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let destination = urlString
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
        return "[\(display)](\(destination))"
    }
}
