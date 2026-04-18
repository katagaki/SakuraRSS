import Foundation

extension ArticleExtractor {

    /// Resolves a potentially relative URL string against a base URL.
    /// Returns the resolved absolute URL string, or nil if it can't be resolved.
    static func resolveURL(_ src: String, against baseURL: URL?) -> String? {
        // Already absolute
        if src.hasPrefix("http://") || src.hasPrefix("https://") {
            return src
        }
        // Protocol-relative
        if src.hasPrefix("//"), let url = URL(string: "https:\(src)") {
            #if DEBUG
            debugPrint("[Image] Resolved protocol-relative URL: \(src) -> \(url.absoluteString)")
            #endif
            return url.absoluteString
        }
        // Relative - needs base URL
        if let baseURL, let resolved = URL(string: src, relativeTo: baseURL) {
            #if DEBUG
            debugPrint("[Image] Resolved relative URL: \(src) -> \(resolved.absoluteString) (base: \(baseURL.absoluteString))")
            #endif
            return resolved.absoluteString
        }
        #if DEBUG
        debugPrint("[Image] Failed to resolve URL: \(src) (base: \(baseURL?.absoluteString ?? "nil"))")
        #endif
        return nil
    }

    /// Resolves relative URLs inside Markdown links (`[text](url)`) against a base URL.
    /// Also percent-encodes spaces in link URLs.
    static func resolveMarkdownLinks(in text: String, baseURL: URL?) -> String {
        guard let baseURL else { return text }
        let pattern = #"\[([^\]]*)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        var result = text
        let nsText = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsText.length))
        for match in matches.reversed() {
            var url = nsText.substring(with: match.range(at: 2))
            if url.hasPrefix("http://") || url.hasPrefix("https://") { continue }
            url = url.replacingOccurrences(of: " ", with: "%20")
            if url.hasPrefix("//"), let abs = URL(string: "https:\(url)") {
                url = abs.absoluteString
            } else if let resolved = URL(string: url, relativeTo: baseURL) {
                url = resolved.absoluteString
            } else {
                continue
            }
            let linkText = nsText.substring(with: match.range(at: 1))
            let replacement = "[\(linkText)](\(url))"
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
