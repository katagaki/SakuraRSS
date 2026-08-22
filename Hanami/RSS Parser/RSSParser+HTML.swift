import Foundation

nonisolated private let rssLinkRegex = try? NSRegularExpression(
    pattern: #"<a\s[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#
)
nonisolated private let rssSupSubRegex = try? NSRegularExpression(
    pattern: #"\{\{(SUP|SUB)\}\}(.+?)\{\{/(SUP|SUB)\}\}"#
)
nonisolated private let rssMarkdownLinkRegex = try? NSRegularExpression(
    pattern: #"\[([^\]]+)\]\(([^)]+)\)"#
)
nonisolated private let rssPreTagRegex = try? NSRegularExpression(
    pattern: #"<pre(?:\s[^>]*)?>(?:\s*<code(?:\s[^>]*)?>)?(.*?)(?:</code>\s*)?</pre>"#,
    options: [.caseInsensitive, .dotMatchesLineSeparators]
)
nonisolated private let rssLineBreakRegex = try? NSRegularExpression(
    pattern: #"<br\s*/?>"#, options: .caseInsensitive
)
nonisolated private let rssBlockTagRegex = try? NSRegularExpression(
    pattern: #"</(?:p|div|li)>"#, options: .caseInsensitive
)
nonisolated private let rssBlankLineRegex = try? NSRegularExpression(pattern: #"\n{3,}"#)
nonisolated private let rssWhitespaceRegex = try? NSRegularExpression(pattern: #"\s+"#)

nonisolated private let rssInlineMarkupRules: [(regex: NSRegularExpression, template: String)] = {
    var specs: [(String, String)] = [
        (#"<h1(?:\s[^>]*)?>(.+?)</h1>"#, "\n# $1\n"),
        (#"<h2(?:\s[^>]*)?>(.+?)</h2>"#, "\n## $1\n"),
        (#"<h3(?:\s[^>]*)?>(.+?)</h3>"#, "\n### $1\n")
    ]
    for tag in ["h4", "h5", "h6"] {
        specs.append(("<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", "\n**$1**\n"))
    }
    for tag in ["strong", "b"] {
        specs.append(("<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", "**$1**"))
    }
    for tag in ["em", "i"] {
        specs.append(("<\(tag)(?:\\s[^>]*)?>(.+?)</\(tag)>", "*$1*"))
    }
    specs.append((#"<sup(?:\s[^>]*)?>(.+?)</sup>"#, "{{SUP}}$1{{/SUP}}"))
    specs.append((#"<sub(?:\s[^>]*)?>(.+?)</sub>"#, "{{SUB}}$1{{/SUB}}"))
    specs.append((#"<code(?:\s[^>]*)?>(.+?)</code>"#, "`$1`"))

    return specs.compactMap { pattern, template in
        guard let regex = try? NSRegularExpression(
            pattern: pattern, options: .caseInsensitive
        ) else { return nil }
        return (regex, template)
    }
}()

public nonisolated extension RSSParser {

    func cleanHTML(_ html: String) -> String? {
        let decoded = RSSParser.decodeHTMLEntities(RSSParser.stripHTMLTags(html))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return decoded.isEmpty ? nil : decoded
    }

    func cleanHTMLPreservingStructure(_ html: String, baseURL: URL? = nil) -> String? {
        guard html.contains("<") else {
            let decoded = RSSParser.decodeHTMLEntities(html)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return decoded.isEmpty ? nil : decoded
        }

        var result = RSSParser.replaceMatches(rssLineBreakRegex, in: html, with: "\n")
        result = convertLinksToMarkdown(result, baseURL: baseURL)
        result = convertInlineMarkup(result)
        result = stripInvalidURLSupSub(result)
        result = RSSParser.replaceMatches(rssBlockTagRegex, in: result, with: "\n")
        result = replacePreTagsWithMarkers(result)
        result = replaceImgTagsWithMarkers(result)
        result = RSSParser.decodeHTMLEntities(RSSParser.stripHTMLTags(result))
        result = RSSParser.replaceMatches(rssBlankLineRegex, in: result, with: "\n\n")

        result = result
            .components(separatedBy: "\n")
            .filter { !isAdvertisementLabel($0) }
            .joined(separator: "\n")

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    internal static func replaceMatches(
        _ regex: NSRegularExpression?, in text: String, with template: String
    ) -> String {
        guard let regex else { return text }
        let nsText = text as NSString
        return regex.stringByReplacingMatches(
            in: text, range: NSRange(location: 0, length: nsText.length), withTemplate: template
        )
    }

    private func convertLinksToMarkdown(_ text: String, baseURL: URL? = nil) -> String {
        guard let linkRegex = rssLinkRegex else { return text }

        var result = text
        let nsResult = result as NSString
        let linkMatches = linkRegex.matches(
            in: result, range: NSRange(location: 0, length: nsResult.length)
        )
        for match in linkMatches.reversed() {
            var url = nsResult.substring(with: match.range(at: 1))
            let linkText = RSSParser.replaceMatches(
                rssWhitespaceRegex, in: nsResult.substring(with: match.range(at: 2)), with: " "
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if linkText.isEmpty {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            } else {
                url = url.markdownLinkSafeURL
                if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                    if url.hasPrefix("//"), let absolute = URL(string: "https:\(url)") {
                        url = absolute.absoluteString
                    } else if let baseURL, let resolved = URL(string: url, relativeTo: baseURL) {
                        url = resolved.absoluteString
                    }
                }
                let escaped = linkText
                    .replacingOccurrences(of: "[", with: "\\[")
                    .replacingOccurrences(of: "]", with: "\\]")
                let replacement = "[\(escaped)](\(url))"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    private func convertInlineMarkup(_ text: String) -> String {
        var result = text
        for rule in rssInlineMarkupRules {
            result = RSSParser.replaceMatches(rule.regex, in: result, with: rule.template)
        }
        return result
    }

    func stripInvalidURLSupSub(_ text: String) -> String {
        guard let regex = rssSupSubRegex else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            let content = nsText.substring(with: match.range(at: 2))
            if let linkRegex = rssMarkdownLinkRegex,
               let linkMatch = linkRegex.firstMatch(
                in: content, range: NSRange(location: 0, length: (content as NSString).length)
               ) {
                let urlString = (content as NSString).substring(with: linkMatch.range(at: 2))
                if URL(string: urlString) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            } else if content.hasPrefix("http://") || content.hasPrefix("https://")
                        || content.hasPrefix("//") {
                if URL(string: content) == nil {
                    result = (result as NSString).replacingCharacters(in: match.range, with: "")
                }
            }
        }
        return result
    }

    private func replacePreTagsWithMarkers(_ text: String) -> String {
        guard let regex = rssPreTagRegex else { return text }
        var result = text
        let nsResult = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            var content = nsResult.substring(with: match.range(at: 1))
            content = RSSParser.stripHTMLTags(content)
            content = content.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            if !content.isEmpty {
                let replacement = "\n{{CODE}}\(content){{/CODE}}\n"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    private func isAdvertisementLabel(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed == "advertisement" || trimmed == "advertising"
    }
}
