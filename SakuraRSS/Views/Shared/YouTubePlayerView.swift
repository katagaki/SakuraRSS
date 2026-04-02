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
    @State private var isAd = false
    @State private var advertiserURL: URL?
    @State private var hasStartedPlaying = false
    @State private var videoAspectRatio: CGFloat = 16 / 9
    @State private var feed: Feed?
    @State private var favicon: UIImage?
    @State private var acronymIcon: UIImage?

    private var youtubeAppURL: URL? {
        guard let url = URL(string: article.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "youtube"
        return components.url
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let favicon {
            FaviconImage(favicon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            FaviconImage(acronymIcon, size: 36, circle: true, skipInset: true)
        } else if let feed {
            InitialsAvatarView(feed.title, size: 36, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            YouTubePlayerWebView(
                urlString: article.url,
                isPlaying: $isPlaying,
                currentTime: $currentTime,
                duration: $duration,
                webView: $webView,
                isAd: $isAd,
                advertiserURL: $advertiserURL,
                videoAspectRatio: $videoAspectRatio
            )
            .aspectRatio(videoAspectRatio, contentMode: .fit)
            .clipped()
            .overlay {
                if !hasStartedPlaying {
                    Color.black
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }

            ScrollView(.vertical) {
                VStack(spacing: 0) {
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
                        isDisabled: isAd,
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
                        .disabled(isAd)

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
                        .disabled(isAd)

                        Button {
                            enterFullscreen()
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                        }
                    }
                    .foregroundStyle(.primary)
                    .padding(.top, 16)

                    // Visit Advertiser button
                    if isAd, let advertiserURL {
                        Button {
                            openURL(advertiserURL)
                        } label: {
                            Text(String(localized: "YouTube.VisitAdvertiser"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }

                    // Channel info
                    if let feed {
                        HStack(alignment: .top, spacing: 12) {
                            feedAvatarView

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.title)
                                    .font(.subheadline.bold())
                                if let date = article.publishedDate {
                                    RelativeTimeText(date: date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }

                    // Description
                    if let description = article.summary ?? article.content,
                       !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 12)
                    }

                    Spacer()
                        .frame(height: 32)
                }
            }
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
        .onChange(of: isPlaying) { _, newValue in
            if newValue && !hasStartedPlaying {
                withAnimation(.smooth.speed(2.0)) {
                    hasStartedPlaying = true
                }
            }
        }
        .onChange(of: isAd) { _, newValue in
            webView?.isUserInteractionEnabled = newValue
        }
        .task {
            isBookmarked = article.isBookmarked
            let signedIn = await YouTubePlayerView.hasYouTubeSession()
            let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
            isPiPEligible = signedIn && premium

            if let loadedFeed = feedManager.feed(forArticle: article) {
                feed = loadedFeed
                if let data = loadedFeed.acronymIcon {
                    acronymIcon = UIImage(data: data)
                }
                favicon = await FaviconCache.shared.favicon(for: loadedFeed)
            }
        }
    }

}

// MARK: - Playback Controls

extension YouTubePlayerView {

    func togglePlayPause() {
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

    func seek(to time: TimeInterval) {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = \(time); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func rewind() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime = Math.max(0, video.currentTime - 10); }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func fastForward() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) { video.currentTime += 10; }
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func enterFullscreen() {
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

    func togglePiP() {
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
}

// MARK: - Session

extension YouTubePlayerView {

    static func hasYouTubeSession() async -> Bool {
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
