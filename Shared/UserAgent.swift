import Foundation

// swiftlint:disable line_length
nonisolated let sakuraUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
// swiftlint:enable line_length

extension URLRequest {
    nonisolated static func sakura(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        return request
    }
}
