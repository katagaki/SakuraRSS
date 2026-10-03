import Foundation

/// Recognizes bot-challenge interstitials (Cloudflare, DataDome, PerimeterX, Akamai, Imperva).
public nonisolated enum BotChallengeDetector {

    /// Only markers unique to interstitials; bot vendors also inject scripts into normal pages.
    public static let markers: [String] = [
        "cdn-cgi/challenge-platform/h/",
        "window._cf_chl_opt",
        "<title>Just a moment",
        "checking your browser before accessing",
        "ddos protection by cloudflare",
        "please enable javascript and cookies to continue",
        "geo.captcha-delivery.com",
        "id=\"px-captcha\"",
        "sec-if-cpt-container",
        "incapsula incident id"
    ]

    public static func looksLikeChallenge(_ html: String, response: URLResponse? = nil) -> Bool {
        if let response, responseIsChallenge(response) {
            return true
        }
        let lowered = html.lowercased()
        return markers.contains { marker in
            lowered.contains(marker.lowercased())
        }
    }

    private static func responseIsChallenge(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        if http.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() == "challenge" {
            return true
        }
        return http.statusCode == 403 && http.value(forHTTPHeaderField: "x-datadome") != nil
    }
}
