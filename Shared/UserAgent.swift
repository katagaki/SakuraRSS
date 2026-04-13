import Foundation

// swiftlint:disable line_length
/// Safari-parity User-Agent string sent on every outbound request.
///
/// Marked `nonisolated` because targets in this project build with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise
/// make this top-level `let` MainActor-only and unreachable from the
/// background-thread scrapers that need to stamp it onto requests.
nonisolated let sakuraUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
// swiftlint:enable line_length

extension URLRequest {
    /// Builds a URLRequest preconfigured with the Sakura User-Agent.  Use
    /// this in place of `URLSession.shared.data(from: url)` so outbound
    /// traffic doesn't leak the default `CFNetwork` UA, which advertises
    /// both the app bundle and iOS version and gets flagged by bot
    /// heuristics on a number of CDNs.
    ///
    /// Marked `nonisolated` because targets in this project build with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise
    /// make this extension method MainActor-only and unreachable from
    /// background-thread scrapers.
    nonisolated static func sakura(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}
