import AVFoundation
import SwiftUI
import WebKit
import Hanami

struct YouTubePlayerWebView: UIViewRepresentable {

    let urlString: String
    let session: YouTubePlayerSession
    var autoplay: Bool = true
    @Binding var isPlaying: Bool
    @Binding var webView: WKWebView?
    @Binding var isAd: Bool
    @Binding var isAdSkippable: Bool
    @Binding var advertiserURL: URL?
    @Binding var videoAspectRatio: CGFloat
    @Binding var isPiP: Bool
    var chapters: Binding<[YouTubeChapter]>?
    /// Time callbacks are deliberately not `@Binding`s. SwiftUI reads bindings'
    /// `wrappedValue` inside the parent view's body tracking scope while
    /// diffing the view, which would re-subscribe the parent to whatever
    /// observable backs the binding (causing toolbar/menu rebuilds at every
    /// quarter-second tick when the source is `session.currentTime`).
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onDurationUpdate: ((TimeInterval) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPlaying: $isPlaying,
            isAd: $isAd,
            isAdSkippable: $isAdSkippable,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP,
            chapters: chapters,
            onTimeUpdate: onTimeUpdate,
            onDurationUpdate: onDurationUpdate
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        YouTubeAudioSession.prepare()

        if let existing = reuseExistingWebViewIfMatching(coordinator: context.coordinator) {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.userContentController = makeUserContentController(coordinator: context.coordinator)

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
        let session = self.session
        DispatchQueue.main.async {
            self.webView = webView
            session.webView = webView
        }
        return webView
    }

    private func reuseExistingWebViewIfMatching(coordinator: Coordinator) -> WKWebView? {
        guard let existing = session.webView,
              session.currentArticle?.url == urlString else {
            return nil
        }
        existing.removeFromSuperview()
        existing.navigationDelegate = coordinator
        existing.isUserInteractionEnabled = false
        let userContent = existing.configuration.userContentController
        userContent.removeAllScriptMessageHandlers()
        userContent.add(coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        userContent.add(coordinator, name: YouTubePlayerScripts.playbackMessageHandlerName)
        #if DEBUG
        userContent.add(coordinator, name: "ytDebug")
        #endif
        DispatchQueue.main.async {
            self.webView = existing
            existing.evaluateJavaScript(
                "window.__ytPrimePlayback && window.__ytPrimePlayback();",
                completionHandler: nil
            )
        }
        return existing
    }

    private func makeUserContentController(coordinator: Coordinator) -> WKUserContentController {
        let controller = WKUserContentController()
        let scripts: [InjectedUserScript] = [
            .init(source: YouTubePlayerScripts.mediaIsolationBootstrap, time: .atDocumentStart, mainFrameOnly: false),
            .init(
                source: YouTubePlayerStyles.injectionScript(css: YouTubePlayerStyles.css),
                time: .atDocumentStart,
                mainFrameOnly: true
            ),
            .init(source: YouTubePlayerScripts.pauseGuard, time: .atDocumentEnd, mainFrameOnly: false),
            .init(source: YouTubePlayerScripts.autoplayArmer, time: .atDocumentEnd, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.pipEventBridge, time: .atDocumentEnd, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.pipDisableOverride, time: .atDocumentStart, mainFrameOnly: true),
            .init(
                source: YouTubePlayerScripts.mediaSessionUserActionBridge,
                time: .atDocumentStart,
                mainFrameOnly: true
            ),
            .init(source: YouTubePlayerScripts.pipAdControls, time: .atDocumentStart, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.autoPipTargetBridge, time: .atDocumentEnd, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.inactivitySuppressor, time: .atDocumentEnd, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.playbackEventBridge, time: .atDocumentEnd, mainFrameOnly: true)
        ]
        for script in scripts {
            controller.addUserScript(WKUserScript(
                source: script.source,
                injectionTime: script.time,
                forMainFrameOnly: script.mainFrameOnly
            ))
        }
        if !autoplay {
            controller.addUserScript(WKUserScript(
                source: YouTubePlayerScripts.autoplayBlocker,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }
        controller.add(coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        controller.add(coordinator, name: YouTubePlayerScripts.playbackMessageHandlerName)
        #if DEBUG
        controller.add(coordinator, name: "ytDebug")
        #endif
        return controller
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
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: YouTubePlayerScripts.pipMessageHandlerName
        )
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: YouTubePlayerScripts.playbackMessageHandlerName
        )
        #if DEBUG
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "ytDebug")
        #endif
        // Leave the WKWebView alive if the session still owns it so audio
        // continues while collapsed into the tab bar bottom accessory.
    }
}
