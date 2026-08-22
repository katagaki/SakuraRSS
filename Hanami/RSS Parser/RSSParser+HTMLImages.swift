import Foundation

nonisolated private let rssImgElementRegex = try? NSRegularExpression(
    pattern: #"<img\b[^>]*>"#, options: .caseInsensitive
)

nonisolated private let rssLazyImageAttributes = [
    "data-src", "data-original", "data-lazy-src", "data-lazy", "data-srcset", "srcset"
]

nonisolated private let rssImageAttributeRegexes: [String: NSRegularExpression] = {
    var regexes: [String: NSRegularExpression] = [:]
    for name in ["src"] + rssLazyImageAttributes {
        let pattern = #"(?<![-\w])\#(name)\s*=\s*["']([^"']*)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            regexes[name] = regex
        }
    }
    return regexes
}()

nonisolated private let rssBlockedImageTokens: Set<String> = [
    "gravatar", "feedburner", "doubleclick", "googlesyndication",
    "pixel", "spacer", "blank", "1x1", "transparent", "tracking", "beacon",
    "badge", "icon", "icons", "emoji", "smiley", "avatar", "ad", "ads"
]

public nonisolated extension RSSParser {

    func extractImageFromHTML(_ html: String) -> String? {
        let candidates = imageSourceCandidates(in: html)
        return candidates.first(where: { isLikelyHeroImage($0) }) ?? candidates.first
    }

    func isLikelyHeroImage(_ url: String) -> Bool {
        let tokens = url.lowercased().split { !$0.isLetter && !$0.isNumber }
        return !tokens.contains { rssBlockedImageTokens.contains(String($0)) }
    }

    func replaceImgTagsWithMarkers(_ text: String) -> String {
        guard let regex = rssImgElementRegex else { return text }
        var result = text
        let nsResult = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
        for match in matches.reversed() {
            let imageURL = imageSource(inTag: nsResult.substring(with: match.range))
            if let imageURL, isLikelyHeroImage(imageURL) {
                let replacement = "\n{{IMG}}\(imageURL){{/IMG}}\n"
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            } else {
                result = (result as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        return result
    }

    private func imageSourceCandidates(in html: String) -> [String] {
        guard let regex = rssImgElementRegex else { return [] }
        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))
        return matches.compactMap { imageSource(inTag: nsHTML.substring(with: $0.range)) }
    }

    private func imageSource(inTag tag: String) -> String? {
        let source = imageAttributeValue("src", inTag: tag)
        if let source, !source.lowercased().hasPrefix("data:") {
            return source
        }
        for name in rssLazyImageAttributes {
            guard let raw = imageAttributeValue(name, inTag: tag) else { continue }
            let value = name.hasSuffix("srcset") ? firstSourceSetURL(raw) : raw
            if let value, !value.isEmpty, !value.lowercased().hasPrefix("data:") {
                return value
            }
        }
        return source
    }

    private func imageAttributeValue(_ name: String, inTag tag: String) -> String? {
        guard let regex = rssImageAttributeRegexes[name] else { return nil }
        let nsTag = tag as NSString
        guard let match = regex.firstMatch(
            in: tag, range: NSRange(location: 0, length: nsTag.length)
        ), match.numberOfRanges >= 2 else { return nil }
        let value = nsTag.substring(with: match.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func firstSourceSetURL(_ value: String) -> String? {
        guard let firstEntry = value.split(separator: ",").first,
              let url = firstEntry.split(whereSeparator: { $0.isWhitespace }).first else {
            return nil
        }
        return String(url)
    }
}
