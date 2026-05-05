import AVFoundation
import SwiftUI
import WebKit

struct YouTubePlayerWebView: UIViewRepresentable {

    let urlString: String
    var autoplay: Bool = true
    @Binding var isPlaying: Bool
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    @Binding var webView: WKWebView?
    @Binding var isAd: Bool
    @Binding var isAdSkippable: Bool
    @Binding var advertiserURL: URL?
    @Binding var videoAspectRatio: CGFloat
    @Binding var isPiP: Bool
    var chapters: Binding<[YouTubeChapter]>?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            isAd: $isAd,
            isAdSkippable: $isAdSkippable,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP,
            chapters: chapters
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        YouTubeAudioSession.prepare()

        if let existing = YouTubePlayerSession.shared.webView,
           YouTubePlayerSession.shared.currentArticle?.url == urlString {
            existing.removeFromSuperview()
            existing.navigationDelegate = context.coordinator
            existing.isUserInteractionEnabled = false
            let userContent = existing.configuration.userContentController
            userContent.removeAllScriptMessageHandlers()
            userContent.add(context.coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
            #if DEBUG
            userContent.add(context.coordinator, name: "ytDebug")
            #endif
            DispatchQueue.main.async {
                self.webView = existing
                context.coordinator.startPlaybackObserver(for: existing)
            }
            return existing
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.mediaIsolationBootstrap,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerStyles.injectionScript(css: YouTubePlayerStyles.css),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.pauseGuard,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.autoplayArmer,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.pipEventBridge,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.pipDisableOverride,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.mediaSessionUserActionBridge,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        controller.addUserScript(WKUserScript(
            source: YouTubePlayerScripts.pipAdControls,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        if !autoplay {
            controller.addUserScript(WKUserScript(
                source: YouTubePlayerScripts.autoplayBlocker,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }
        controller.add(context.coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        #if DEBUG
        controller.add(context.coordinator, name: "ytDebug")
        #endif
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.customUserAgent = sakuraUserAgent
        webView.isUserInteractionEnabled = false
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: Self.normalizedURL(url)))
        }
        DispatchQueue.main.async {
            self.webView = webView
            YouTubePlayerSession.shared.webView = webView
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// Rewrites Shorts URLs to the regular watch URL so the WebView uses the standard player.
    static func normalizedURL(_ url: URL) -> URL {
        let path = url.path
        guard path.hasPrefix("/shorts/") else { return url }
        let videoID = String(path.dropFirst("/shorts/".count))
            .split(separator: "/").first.map(String.init) ?? ""
        guard !videoID.isEmpty,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.path = "/watch"
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "v" }
        items.insert(URLQueryItem(name: "v", value: videoID), at: 0)
        components.queryItems = items
        return components.url ?? url
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.invalidateObserver()
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: YouTubePlayerScripts.pipMessageHandlerName
        )
        #if DEBUG
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "ytDebug")
        #endif
        // Leave the WKWebView alive if the session still owns it so audio
        // continues while collapsed into the tab bar bottom accessory.
    }
}
