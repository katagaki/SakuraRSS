import Foundation
import WebKit

/// Whether YouTube is signed in, judged from its cookies in the shared web
/// view store, and signing it out again.
enum YouTubeWebSession {

    private static let cacheKey = "YouTubePlayerView.hasSession"

    static func hasSession() async -> Bool {
        if await cookiesShowSession() {
            UserDefaults.standard.set(true, forKey: cacheKey)
            return true
        }
        // Retry once so WebKit can finish loading cookies from disk.
        if UserDefaults.standard.bool(forKey: cacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await cookiesShowSession()
            UserDefaults.standard.set(retryResult, forKey: cacheKey)
            return retryResult
        }
        UserDefaults.standard.set(false, forKey: cacheKey)
        return false
    }

    static func clearSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("youtube.com")
            || cookie.domain.lowercased().contains("google.com")
            || cookie.domain.lowercased().contains("accounts.google.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        UserDefaults.standard.set(false, forKey: cacheKey)
    }

    private static func cookiesShowSession() async -> Bool {
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }
    }
}
