import SwiftUI
import WebKit

struct YouTubePlayerView: View {

    @Environment(FeedManager.self) var feedManager
    @Environment(\.openURL) var openURL
    let article: Article

    @State private var isBookmarked = false
    @State private var isPlaying = false
    @State private var isPiPEligible = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
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
        VStack(spacing: 0) {
                YouTubePlayerWebView(
                    urlString: article.url,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    webView: $webView
                )
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipped()

                // Title
                Text(article.title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 12)

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

                // Seek bar
                SeekBarView(
                    currentTime: Binding(
                        get: { currentTime },
                        set: { currentTime = $0 }
                    ),
                    duration: duration,
                    onSeek: { seek(to: $0) }
                )
                .padding(.horizontal)
                .padding(.top, 16)

                // Playback controls
                HStack(spacing: 32) {
                    Button {
                        togglePiP()
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.title2)
                    }

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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isBookmarked.toggle()
                    feedManager.toggleBookmark(article)
                } label: {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isLandscape {
                enterFullscreen()
            }
        }
        .task {
            isBookmarked = article.isBookmarked
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

    private func seek(to time: TimeInterval) {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = \(time); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
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
        // swiftlint:disable line_length
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        // swiftlint:enable line_length

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
