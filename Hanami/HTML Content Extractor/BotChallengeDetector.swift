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
        return containsMarker(html)
    }

    /// Off the caller's actor, for polling whole rendered pages.
    @concurrent public static func looksLikeChallengeOffMainActor(_ html: String) async -> Bool {
        looksLikeChallenge(html)
    }

    private static let lowercasedMarkers: [[UInt8]] = markers.map { Array($0.lowercased().utf8) }

    /// Matches the ASCII markers case-insensitively over the UTF-8 bytes; lowercasing
    /// a multi-megabyte page first took tens of milliseconds per check.
    private static func containsMarker(_ html: String) -> Bool {
        var html = html
        return html.withUTF8 { bytes in
            guard !bytes.isEmpty else { return false }
            for start in bytes.indices {
                let first = asciiLowercased(bytes[start])
                for marker in lowercasedMarkers where marker[0] == first && start + marker.count <= bytes.count {
                    var offset = 1
                    while offset < marker.count, asciiLowercased(bytes[start + offset]) == marker[offset] {
                        offset += 1
                    }
                    if offset == marker.count {
                        return true
                    }
                }
            }
            return false
        }
    }

    private static func asciiLowercased(_ byte: UInt8) -> UInt8 {
        (byte >= 65 && byte <= 90) ? byte + 32 : byte
    }

    private static func responseIsChallenge(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        if http.value(forHTTPHeaderField: "cf-mitigated")?.lowercased() == "challenge" {
            return true
        }
        return http.statusCode == 403 && http.value(forHTTPHeaderField: "x-datadome") != nil
    }
}
