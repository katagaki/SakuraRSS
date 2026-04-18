import Foundation

/// Detects publisher paywalls so the UI can surface a "open in Safari"
/// banner instead of caching a truncated teaser as if it were the article.
nonisolated enum PaywallDetector {

    /// Minimal textual signals — matched against the lowercased first 2 KB
    /// of extracted text.
    static let textPatterns: [String] = [
        "subscribe to continue",
        "subscribe to keep reading",
        "subscribe now to continue",
        "this article is for subscribers",
        "this story is for subscribers",
        "already a subscriber",
        "already have an account",
        "register to keep reading",
        "register to continue reading",
        "please sign in to continue",
        "please sign in to read",
        "sign in to continue reading",
        "create a free account to continue",
        "log in to read the rest",
        "unlock this article",
        "unlock unlimited access",
        "become a subscriber to read",
        "you've reached your article limit",
        "this content is reserved"
    ]

    /// Returns `true` when the HTTP response or the extracted text contain
    /// recognizable paywall signals.
    static func detect(
        response: URLResponse?,
        extractedText: String?
    ) -> Bool {
        if let http = response as? HTTPURLResponse,
           (401...403).contains(http.statusCode) {
            return true
        }
        guard let extractedText else { return false }
        let lowered = String(extractedText.prefix(2000)).lowercased()
        return textPatterns.contains(where: lowered.contains)
    }

    /// Returns `true` when the raw HTML includes common markup signals
    /// for a paywall gate (regwall overlay, subscriber-only metadata).
    static func htmlSuggestsPaywall(_ html: String) -> Bool {
        let lowered = html.lowercased()
        let markers = [
            "meta name=\"articleaccess\" content=\"subscriber",
            "data-testid=\"paywall",
            "class=\"paywall",
            "id=\"paywall",
            "data-paywall",
            "<meta property=\"article:content_tier\" content=\"locked"
        ]
        return markers.contains(where: lowered.contains)
    }
}
