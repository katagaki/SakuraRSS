import Foundation
import SwiftSoup

extension ArticleExtractor {

    // MARK: - HTML Tag Replacement

    /// Converts `<a><img></a>` patterns to image placeholders with link info.
    static func replaceLinkedImgTags(in html: String, baseURL: URL? = nil) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>\\s*<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>\\s*</a>",
            options: .caseInsensitive
        ) else { return html }
        var result = html
        let nsHTML = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))
        for match in matches.reversed() {
            let linkURL = nsHTML.substring(with: match.range(at: 1))
            let imgURL = nsHTML.substring(with: match.range(at: 2))
            if isLikelyContentImage(imgURL),
               let resolvedImg = resolveURL(imgURL, against: baseURL) {
                let resolvedLink = resolveURL(linkURL, against: baseURL) ?? linkURL
                // swiftlint:disable:next line_length
                let replacement = "\(imgOpenPlaceholder)\(resolvedImg)\(imgLinkOpenPlaceholder)\(resolvedLink)\(imgLinkClosePlaceholder)\(imgClosePlaceholder)"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        return result
    }

    static func replaceImgTags(in html: String, baseURL: URL? = nil) -> String {
        guard let imgRegex = try? NSRegularExpression(
            pattern: "<img\\s[^>]*src=[\"']([^\"']+)[\"'][^>]*/?>",
            options: .caseInsensitive
        ) else { return html }
        var result = html
        let nsHTML = result as NSString
        let imgMatches = imgRegex.matches(in: result, range: NSRange(location: 0, length: nsHTML.length))
        for match in imgMatches.reversed() {
            let imgURL = nsHTML.substring(with: match.range(at: 1))
            if isLikelyContentImage(imgURL), let resolved = resolveURL(imgURL, against: baseURL) {
                log("Image", "Inline <img> extracted: \(resolved)")
                let replacement = "\(imgOpenPlaceholder)\(resolved)\(imgClosePlaceholder)"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            } else {
                log("Image", "Inline <img> skipped: \(imgURL)")
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    static func replaceLinkTags(in html: String) -> String {
        var result = html

        result = result.replacingOccurrences(
            of: "<a\\s[^>]*>\\s*</a>",
            with: "",
            options: .regularExpression
        )

        // Use NSRegularExpression so newline placeholders inside link text
        // can be collapsed; a plain regex substitution would preserve them
        // and produce broken Markdown like `[\nText\n](url)`.
        guard let regex = try? NSRegularExpression(
            pattern: "<a\\s[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.+?)</a>",
            options: .caseInsensitive
        ) else { return result }

        let nsResult = result as NSString
        let matches = regex.matches(in: result,
                                    range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            let href = nsResult.substring(with: match.range(at: 1))
            var linkText = nsResult.substring(with: match.range(at: 2))
            linkText = linkText
                .replacingOccurrences(of: doubleLFPlaceholder, with: " ")
                .replacingOccurrences(of: singleLFPlaceholder, with: " ")
            let visibleText = linkText
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if visibleText.isEmpty || visibleText == href {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
                continue
            }
            let replacement = "\(linkOpenPlaceholder)\(linkText)\(linkMidPlaceholder)\(href)\(linkClosePlaceholder)"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    static func replaceFormattingTags(in html: String) -> String {
        var result = html
        for tag in ["strong", "b"] {
            result = result.replacingOccurrences(
                of: "<\(tag)(?:\\s[^>]*)?>", with: boldOpenPlaceholder,
                options: [.regularExpression, .caseInsensitive]
            )
            result = result.replacingOccurrences(
                of: "</\(tag)>", with: boldClosePlaceholder, options: .caseInsensitive
            )
        }
        result = result.replacingOccurrences(
            of: "<em(?:\\s[^>]*)?>", with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</em>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: #"<i(?:\s[^>]*)?>"#, with: italicOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</i>", with: italicClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: "<sup(?:\\s[^>]*)?>", with: supOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</sup>", with: supClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: "<sub(?:\\s[^>]*)?>", with: subOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</sub>", with: subClosePlaceholder, options: .caseInsensitive
        )
        result = result.replacingOccurrences(
            of: "<code(?:\\s[^>]*)?>", with: codeOpenPlaceholder,
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "</code>", with: codeClosePlaceholder, options: .caseInsensitive
        )
        return result
    }
}
