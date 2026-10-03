import Foundation

extension InstagramProvider {
    /// Mirrors a Safari navigation: text/html Accept, document fetch dest,
    /// no XHR/CSRF headers (the XHR variant returns a JSON shell rather
    /// than the server-rendered comments).
    func buildHTMLRequest(
        url: URL, referer: String = "https://www.instagram.com/"
    ) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: max(5, requestTimeoutInterval))
        request.setValue(sakuraUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        request.setValue(Self.acceptLanguageHeader, forHTTPHeaderField: "Accept-Language")
        request.setValue(referer, forHTTPHeaderField: "referer")
        request.setValue("https://www.instagram.com", forHTTPHeaderField: "origin")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("navigate", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("document", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("?1", forHTTPHeaderField: "sec-fetch-user")

        return request
    }
}
