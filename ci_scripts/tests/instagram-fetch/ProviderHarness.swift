import Foundation

@MainActor
final class InstagramProvider {
    static let targetPostCount = 50

    struct InstagramCookies {
        let csrfToken: String
        let sessionID: String
        let allCookies: [HTTPCookie]
    }

    func buildRequest(url: URL, cookies: InstagramCookies, referer: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(cookies.csrfToken, forHTTPHeaderField: "x-csrftoken")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        return request
    }
}

func log(_ category: String, _ message: String) {}
