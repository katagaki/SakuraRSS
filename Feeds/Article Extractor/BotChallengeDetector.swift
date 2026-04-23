import Foundation

/// Recognizes Cloudflare / Akamai / PerimeterX bot-challenge pages so extraction can fall back to WebView.
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
