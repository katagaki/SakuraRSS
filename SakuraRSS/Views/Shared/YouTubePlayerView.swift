import SwiftUI
import WebKit

struct YouTubePlayerView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    let article: Article

    @State private var isPlaying = false
    @State private var isPiPEligible = false
    @State private var webView: WKWebView?

    private var youtubeAppURL: URL? {
        guard let url = URL(string: article.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "youtube"
        return components.url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                YouTubePlayerWebView(
                    urlString: article.url,
                    isPlaying: $isPlaying,
                    webView: $webView
                )
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()

                // Action toolbar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let youtubeAppURL, UIApplication.shared.canOpenURL(youtubeAppURL) {
                            Button {
                                UIApplication.shared.open(youtubeAppURL)
                            } label: {
                                Label(
                                    String(localized: "YouTube.OpenInApp"),
                                    systemImage: "play.rectangle"
                                )
                                .padding(.horizontal, 2)
                                .padding(.vertical, 2)
                            }
                        }

                        Button {
                            if let url = URL(string: article.url) {
                                openURL(url)
                            }
                        } label: {
                            Label(
                                String(localized: "YouTube.OpenInBrowser"),
                                systemImage: "safari"
                            )
                            .padding(.horizontal, 2)
                            .padding(.vertical, 2)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .padding(.horizontal)
                }
                .padding(.top, 12)

                // Playback controls
                HStack(spacing: 32) {
                    Button {
                        togglePiP()
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.title2)
                    }
                    .disabled(!isPiPEligible)

                    Button {
                        rewind()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                    }

                    Button {
                        togglePlayPause()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                    }

                    Button {
                        fastForward()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                    }

                    Button {
                        enterFullscreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.title2)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.top, 16)

                Spacer()
            }
            .sakuraBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(article.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            let signedIn = await YouTubePlayerView.hasYouTubeSession()
            let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
            isPiPEligible = signedIn && premium
        }
    }

    private func togglePlayPause() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (video.paused) { video.play(); } else { video.pause(); }
                return !video.paused;
            }
            return null;
        })();
        """
        webView?.evaluateJavaScript(script) { result, _ in
            if let playing = result as? Bool {
                isPlaying = playing
            }
        }
    }

    private func rewind() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = Math.max(0, video.currentTime - 10); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func fastForward() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime += 10; }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func enterFullscreen() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && video.webkitEnterFullscreen) {
                video.webkitEnterFullscreen();
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func togglePiP() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                if (document.pictureInPictureElement) {
                    document.exitPictureInPicture();
                } else if (video.requestPictureInPicture) {
                    video.requestPictureInPicture();
                }
            }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    static func hasYouTubeSession() async -> Bool {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            return (domain.contains("youtube.com") || domain.contains("google.com"))
                && (cookie.name == "SID" || cookie.name == "SSID" || cookie.name == "LOGIN_INFO")
        }
    }

    /// Checks if the signed-in user has YouTube Premium by looking for
    /// premium membership indicators in YouTube's initial page data.
    static func hasYouTubePremium() async -> Bool {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        return await withCheckedContinuation { continuation in
            let delegate = PremiumCheckDelegate { isPremium in
                continuation.resume(returning: isPremium)
            }
            webView.navigationDelegate = delegate
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.load(URLRequest(url: URL(string: "https://m.youtube.com/")!))
        }
    }

    static func clearYouTubeSession() async {
        let store = WKWebsiteDataStore.default()
        let cookies = await store.httpCookieStore.allCookies()
        for cookie in cookies where cookie.domain.lowercased().contains("youtube.com")
            || cookie.domain.lowercased().contains("google.com")
            || cookie.domain.lowercased().contains("accounts.google.com") {
            await store.httpCookieStore.deleteCookie(cookie)
        }
    }
}

private struct YouTubePlayerWebView: UIViewRepresentable {

    let urlString: String
    @Binding var isPlaying: Bool
    @Binding var webView: WKWebView?

    func makeCoordinator() -> Coordinator {
        Coordinator(isPlaying: $isPlaying)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        DispatchQueue.main.async {
            self.webView = webView
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isPlaying: Bool
        private var playbackObserver: Timer?

        init(isPlaying: Binding<Bool>) {
            _isPlaying = isPlaying
        }

        deinit {
            playbackObserver?.invalidate()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectStyles(into: webView)
            startPlaybackObserver(for: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            let host = url.host?.lowercased() ?? ""

            // Allow YouTube and Google auth navigation
            if host.contains("youtube.com") || host.contains("youtu.be")
                || host.contains("google.com") || host.contains("accounts.google.com")
                || host.contains("consent.youtube.com") {
                return .allow
            }

            // Block external navigation
            return .cancel
        }

        private func injectStyles(into webView: WKWebView) {
            let css = """
            * { margin: 0 !important; padding: 0 !important; }
            body { overflow: hidden !important; background: #000 !important; }
            #player, .html5-video-player, video {
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                z-index: 999999 !important;
            }
            ytd-app, #content, #page-manager, ytd-watch-flexy,
            #columns, #primary, #primary-inner, #player-container-outer,
            #player-container-inner, #player-container,
            #movie_player, .html5-video-container {
                position: fixed !important;
                top: 0 !important; left: 0 !important;
                width: 100vw !important; height: 100vh !important;
                max-width: none !important; max-height: none !important;
                min-width: 0 !important; min-height: 0 !important;
                margin: 0 !important; padding: 0 !important;
                overflow: hidden !important;
            }
            #secondary, #related, #comments, #info, #meta,
            #above-the-fold, #below, ytd-watch-metadata,
            #masthead-container, #guide, ytd-masthead,
            ytd-mini-guide-renderer, #chat, .ytp-chrome-top,
            .ytp-pause-overlay, .ytp-endscreen-content,
            .ytp-chrome-bottom, .ytp-gradient-bottom,
            .ytp-gradient-top, ytd-engagement-panel-section-list-renderer,
            tp-yt-app-drawer, #description, #actions,
            ytd-merch-shelf-renderer, ytd-info-panel-content-renderer,
            .ytd-watch-next-secondary-results-renderer,
            #chips, #header, .ytd-rich-grid-renderer,
            ytd-feed-filter-chip-bar-renderer,
            ytd-compact-promoted-video-renderer,
            .ytp-ce-element, .ytp-cards-teaser,
            .ytp-paid-content-overlay, .iv-branding,
            tp-yt-paper-dialog, ytd-popup-container,
            #movie_player .ytp-chrome-bottom,
            ytd-consent-bump-v2-lightbox {
                display: none !important;
                visibility: hidden !important;
                height: 0 !important;
                width: 0 !important;
                opacity: 0 !important;
                pointer-events: none !important;
            }
            """

            let script = """
            (function() {
                var style = document.createElement('style');
                style.textContent = `\(css)`;
                document.head.appendChild(style);

                // Re-apply after dynamic content loads
                var observer = new MutationObserver(function() {
                    if (!document.getElementById('sakura-yt-style')) {
                        var s = document.createElement('style');
                        s.id = 'sakura-yt-style';
                        s.textContent = `\(css)`;
                        document.head.appendChild(s);
                    }
                });
                observer.observe(document.body, { childList: true, subtree: true });
            })();
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func startPlaybackObserver(for webView: WKWebView) {
            playbackObserver?.invalidate()
            playbackObserver = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                let script = """
                (function() {
                    var video = document.querySelector('video');
                    return video ? !video.paused : false;
                })();
                """
                webView.evaluateJavaScript(script) { result, _ in
                    if let playing = result as? Bool {
                        DispatchQueue.main.async {
                            self?.isPlaying = playing
                        }
                    }
                }
            }
        }
    }
}

private final class PremiumCheckDelegate: NSObject, WKNavigationDelegate {
    private let completion: (Bool) -> Void
    private var hasCompleted = false

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Check for YouTube Premium by looking for premium membership
        // indicators in YouTube's page data
        let script = """
        (function() {
            try {
                var text = document.documentElement.innerHTML;
                if (text.indexOf('"isPremium":true') !== -1) {
                    return true;
                }
                if (text.indexOf('"hasPaidContent":true') !== -1) {
                    return true;
                }
                if (document.querySelector('[is-premium-member]')) {
                    return true;
                }
                return false;
            } catch(e) {
                return false;
            }
        })();
        """

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, !self.hasCompleted else { return }
            webView.evaluateJavaScript(script) { [weak self] result, _ in
                guard let self, !self.hasCompleted else { return }
                self.hasCompleted = true
                self.completion((result as? Bool) == true)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(false)
    }
}
