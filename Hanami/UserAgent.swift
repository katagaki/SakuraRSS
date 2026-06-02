import Foundation

#if targetEnvironment(macCatalyst)
public nonisolated let sakuraUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Safari/605.1.15"
#else
public nonisolated let sakuraUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.5 Mobile/15E148 Safari/605.1.15"
#endif

public nonisolated var sakuraAcceptLanguage: String {
    let preferred = Locale.preferredLanguages.prefix(5)
    guard !preferred.isEmpty else { return "en-US,en;q=0.9" }
    return preferred.enumerated().map { index, language in
        if index == 0 { return language }
        let quality = max(0.1, 1.0 - Double(index) * 0.1)
        return "\(language);q=\(String(format: "%.1f", quality))"
    }.joined(separator: ",")
}

public extension URLRequest {
    nonisolated static func sakura(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(sakuraAcceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if let host = url.host,
           let scheme = url.scheme,
           let referer = URL(string: "\(scheme)://\(host)/") {
            request.setValue(referer.absoluteString,
                             forHTTPHeaderField: "Referer")
        }
        return request
    }

    /// Image-fetch variant that asks for image/* so origins like
    /// external-preview.redd.it don't serve an HTML wrapper page.
    nonisolated static func sakuraImage(
        url: URL,
        timeoutInterval: TimeInterval = 60
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "image/avif,image/webp,image/*,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if let host = url.host,
           let scheme = url.scheme,
           let referer = URL(string: "\(scheme)://\(host)/") {
            request.setValue(referer.absoluteString,
                             forHTTPHeaderField: "Referer")
        }
        return request
    }
}
