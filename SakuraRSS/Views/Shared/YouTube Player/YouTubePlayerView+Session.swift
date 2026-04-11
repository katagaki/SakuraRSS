import SwiftUI
import WebKit

extension YouTubePlayerView {

    private static let youtubeSessionCacheKey = "YouTubePlayerView.hasSession"

    @MainActor
    static func hasYouTubeSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        let found = cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }

        if found {
            UserDefaults.standard.set(true, forKey: youtubeSessionCacheKey)
            return true
        }

        // Retry once after a delay to let WebKit finish loading cookies from disk.
        if UserDefaults.standard.bool(forKey: youtubeSessionCacheKey) {
            try? await Task.sleep(for: .milliseconds(500))
            let retryResult = await retryHasYouTubeSession()
            UserDefaults.standard.set(retryResult, forKey: youtubeSessionCacheKey)
            return retryResult
        }

        UserDefaults.standard.set(false, forKey: youtubeSessionCacheKey)
        return false
    }

    @MainActor
    private static func retryHasYouTubeSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }
    }

    static func hasYouTubePremium() async -> Bool {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = sakuraUserAgent

        return await withCheckedContinuation { continuation in
            let delegate = PremiumCheckDelegate { isPremium in
                continuation.resume(returning: isPremium)
            }
            webView.navigationDelegate = delegate
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.load(URLRequest(url: URL(string: "https://m.youtube.com/")!))
        }
    }

    @MainActor
    static func clearYouTubeSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("youtube.com")
            || cookie.domain.lowercased().contains("google.com")
            || cookie.domain.lowercased().contains("accounts.google.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
        UserDefaults.standard.set(false, forKey: youtubeSessionCacheKey)
    }
}
