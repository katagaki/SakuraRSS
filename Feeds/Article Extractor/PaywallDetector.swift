import Foundation

/// Detects paywalled articles so the UI can prompt for Safari instead of caching a teaser.
nonisolated enum PaywallDetector {

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

    /// True when the HTTP response status or extracted text matches paywall signals.
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

    /// True when raw HTML contains paywall markup like `data-paywall` or subscriber-only meta tags.
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
