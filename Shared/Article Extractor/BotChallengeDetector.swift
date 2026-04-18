import Foundation

/// Recognizes HTML responses that are bot-challenge interstitials
/// (Cloudflare, Akamai, PerimeterX, …) rather than real article content.
/// Used by the extraction pipeline to short-circuit into WebView
/// extraction, which has a better chance of completing the challenge.
nonisolated enum BotChallengeDetector {

    static let markers: [String] = [
        "cdn-cgi/challenge-platform",
        "<title>Just a moment",
        "window._cf_chl_opt",
        "checking your browser before accessing",
        "ddos protection by cloudflare",
        "ak_bmsc",
        "_px3=",
        "please enable javascript and cookies to continue"
    ]

    static func looksLikeChallenge(_ html: String) -> Bool {
        let lowered = html.lowercased()
        return markers.contains { marker in
            lowered.contains(marker.lowercased())
        }
    }
}
