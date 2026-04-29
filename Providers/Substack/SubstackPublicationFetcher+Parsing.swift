import Foundation

extension SubstackPublicationFetcher {

    /// Extracts the publication's navbar logo image URL from a Substack page's HTML.
    nonisolated static func extractNavbarLogoURL(from html: String) -> String? {
        let anchors = ["data-testid=\"navbar\"", "logoContainer-"]
        for anchor in anchors {
            guard let anchorRange = html.range(of: anchor) else { continue }
            let scopeString = String(html[anchorRange.upperBound...].prefix(20000))
            let pattern = "<img\\b[^>]*\\bsrc=\"([^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(
                      in: scopeString,
                      range: NSRange(scopeString.startIndex..., in: scopeString)
                  ),
                  let range = Range(match.range(at: 1), in: scopeString) else {
                continue
            }
            let src = String(scopeString[range])
            guard src.lowercased().hasPrefix("http") else { continue }
            return upgradedImageURL(src)
        }
        return nil
    }

    /// If the URL is a Substack CDN fetch wrapper, returns the underlying full-resolution URL.
    nonisolated static func upgradedImageURL(_ urlString: String) -> String {
        guard urlString.lowercased().contains("substackcdn.com/image/fetch/") else { return urlString }
        let prefixes = ["https%3A%2F%2F", "https%3a%2f%2f", "http%3A%2F%2F", "http%3a%2f%2f"]
        for prefix in prefixes {
            if let range = urlString.range(of: prefix) {
                let encoded = String(urlString[range.lowerBound...])
                if let decoded = encoded.removingPercentEncoding {
                    return decoded
                }
            }
        }
        return urlString
    }
}
