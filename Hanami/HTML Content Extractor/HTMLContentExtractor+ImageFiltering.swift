import Foundation

public extension HTMLContentExtractor {

    private static let noiseHostSuffixes = [
        "gravatar.com", "feeds.feedburner.com",
        "doubleclick.net", "googlesyndication.com"
    ]

    private static let noiseHostLabels: Set<String> = [
        "ad", "ads", "adserver", "doubleclick", "googlesyndication"
    ]

    private static let noisePathTokens: Set<String> = [
        "pixel", "pixels", "spacer", "blank", "1x1", "transparent",
        "tracking", "tracker", "beacon", "badge", "badges",
        "icon", "icons", "favicon", "emoji", "smiley", "avatar", "avatars"
    ]

    private static let noiseImageExtensions: Set<String> = ["gif", "svg"]

    /// Rejects tracking pixels, chrome, and ad-server images. Matching is done
    /// on host labels and path tokens so words like `upload`, `download`, or
    /// `silicon` are not mistaken for `ad.` or `icon`.
    static func isLikelyContentImage(_ url: String) -> Bool {
        if url.hasPrefix("data:") { return false }
        let lowered = url.lowercased()
        let (host, path) = hostAndPath(of: lowered)
        if let host {
            for suffix in noiseHostSuffixes where host == suffix || host.hasSuffix(".\(suffix)") {
                return false
            }
            for label in host.split(separator: ".") where noiseHostLabels.contains(String(label)) {
                return false
            }
        }
        let tokens = pathTokens(of: path)
        for token in tokens where noisePathTokens.contains(token) {
            return false
        }
        if let fileExtension = imageExtension(of: path),
           noiseImageExtensions.contains(fileExtension) {
            return false
        }
        return true
    }

    private static func hostAndPath(of url: String) -> (host: String?, path: String) {
        var remainder = url
        if let schemeRange = remainder.range(of: "://") {
            remainder = String(remainder[schemeRange.upperBound...])
        } else if remainder.hasPrefix("//") {
            remainder = String(remainder.dropFirst(2))
        } else {
            return (nil, remainder)
        }
        var authority = remainder
        var path = ""
        if let slashIndex = remainder.firstIndex(of: "/") {
            authority = String(remainder[remainder.startIndex..<slashIndex])
            path = String(remainder[slashIndex...])
        }
        if let atIndex = authority.lastIndex(of: "@") {
            authority = String(authority[authority.index(after: atIndex)...])
        }
        if let colonIndex = authority.firstIndex(of: ":") {
            authority = String(authority[authority.startIndex..<colonIndex])
        }
        return (authority.isEmpty ? nil : authority, path)
    }

    private static func pathTokens(of path: String) -> [String] {
        let withoutQuery = path.split(
            separator: "?", maxSplits: 1, omittingEmptySubsequences: false
        ).first.map(String.init) ?? path
        return withoutQuery
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func imageExtension(of path: String) -> String? {
        let withoutQuery = path.split(
            separator: "?", maxSplits: 1, omittingEmptySubsequences: false
        ).first.map(String.init) ?? path
        guard let fileName = withoutQuery.split(separator: "/").last,
              let fileExtension = fileName.split(separator: ".").last,
              fileExtension != fileName else {
            return nil
        }
        return String(fileExtension)
    }
}
