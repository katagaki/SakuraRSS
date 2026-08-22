import SwiftUI
import WebKit
import Hanami

private final class WebViewWarmUpCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func finish() {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume()
    }
}

private final class WebViewWarmUpDelegate: NSObject, WKNavigationDelegate {
    private let onComplete: () -> Void
    private var completed = false

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish() }
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) { finish() }

    private func finish() {
        guard !completed else { return }
        completed = true
        onComplete()
    }
}

extension YouTubePlayerView {

    private static let youtubeSessionCacheKey = "YouTubePlayerView.hasSession"
    private static let warmUpTimeout: TimeInterval = 10

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

        // Retry once so WebKit can finish loading cookies from disk.
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

    /// Hidden WKWebView load to warm the default cookie store before `hasYouTubeSession`.
    @MainActor
    static func warmUpWebView() async {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = sakuraUserAgent

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let completion = WebViewWarmUpCompletion(continuation: continuation)
            let delegate = WebViewWarmUpDelegate { completion.finish() }
            webView.navigationDelegate = delegate
            objc_setAssociatedObject(webView, "warmUpDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            if let url = URL(string: "https://m.youtube.com/") {
                webView.load(URLRequest(url: url))
                // A load that reaches neither `didFinish` nor a failure
                // callback would otherwise hang the caller forever.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.warmUpTimeout) {
                    completion.finish()
                }
            } else {
                completion.finish()
            }
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
