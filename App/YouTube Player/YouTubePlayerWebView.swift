import AVFoundation
import SwiftUI
import WebKit
import Hanami

struct YouTubePlayerWebView {

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
    @Binding var isPlayerReady: Bool
    var chapters: Binding<[YouTubeChapter]>?
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
            isPlayerReady: $isPlayerReady,
            chapters: chapters,
            onTimeUpdate: onTimeUpdate,
            onDurationUpdate: onDurationUpdate
        )
    }

    func makeWebView(coordinator: Coordinator) -> WKWebView {
        YouTubeAudioSession.prepare()

        if let existing = reuseExistingWebViewIfMatching(coordinator: coordinator) {
            return existing
        }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.mediaTypesRequiringUserActionForPlayback = []
        #if os(macOS)
        config.preferences.isElementFullscreenEnabled = true
        // Off by default on the Mac, where it's only exposed to Safari, so
        // the video would report Picture in Picture as unsupported.
        config.preferences.setValue(true, forKey: "allowsPictureInPictureMediaPlayback")
        #else
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        #endif
        config.userContentController = makeUserContentController(coordinator: coordinator)

        let webView = WKWebView(frame: .zero, configuration: config)
        #if DEBUG
        webView.isInspectable = true
        #endif
        webView.navigationDelegate = coordinator
        #if os(macOS)
        webView.underPageBackgroundColor = .black
        #else
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.isUserInteractionEnabled = false
        #endif
        webView.customUserAgent = Self.youTubeUserAgent
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: Self.normalizedURL(url)))
        }
        if autoplay {
            coordinator.beginAutoplayKick(in: webView)
        }
        session.attach(webView: webView, for: urlString)
        DispatchQueue.main.async {
            self.webView = webView
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
        #if !os(macOS)
        existing.isUserInteractionEnabled = false
        #endif
        let userContent = existing.configuration.userContentController
        userContent.removeAllScriptMessageHandlers()
        userContent.add(coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        userContent.add(coordinator, name: YouTubePlayerScripts.playbackMessageHandlerName)
        userContent.add(coordinator, name: "ytDebug")
        coordinator.claimMessageHandlers(on: userContent)
        DispatchQueue.main.async {
            self.webView = existing
            existing.evaluateJavaScript(
                "window.__ytPrimePlayback && window.__ytPrimePlayback();",
                completionHandler: nil
            )
        }
        // `didFinish` never fires on the reuse path, so the new coordinator
        // would otherwise never populate the chapter menu.
        coordinator.reloadChapters(in: existing)
        return existing
    }

    private func makeUserContentController(coordinator: Coordinator) -> WKUserContentController {
        let controller = WKUserContentController()
        let scripts: [InjectedUserScript] = [
            .init(source: YouTubePlayerScripts.mediaIsolationBootstrap, time: .atDocumentStart, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.playbackDiagnostics, time: .atDocumentStart, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.pipEventBridge, time: .atDocumentStart, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.pageEnvironmentMask, time: .atDocumentStart, mainFrameOnly: true),
            .init(
                source: YouTubePlayerStyles.injectionScript(css: YouTubePlayerStyles.css),
                time: .atDocumentStart,
                mainFrameOnly: true
            ),
            .init(source: YouTubePlayerScripts.autoplayArmer, time: .atDocumentEnd, mainFrameOnly: true),
            .init(source: YouTubePlayerScripts.playbackPolicy, time: .atDocumentStart, mainFrameOnly: true),
            .init(
                source: YouTubePlayerScripts.playbackOwnership + YouTubePlayerScripts.mediaSessionPlaybackStateBridge
                    + YouTubePlayerScripts.mediaSessionUserActionBridge,
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
        if autoplay {
            controller.addUserScript(WKUserScript(
                source: YouTubePlayerScripts.initialAutoplayKick,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        } else {
            controller.addUserScript(WKUserScript(
                source: YouTubePlayerScripts.autoplayBlocker,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }
        controller.add(coordinator, name: YouTubePlayerScripts.pipMessageHandlerName)
        controller.add(coordinator, name: YouTubePlayerScripts.playbackMessageHandlerName)
        controller.add(coordinator, name: "ytDebug")
        coordinator.claimMessageHandlers(on: controller)
        return controller
    }

    /// Rewrites Shorts and live URLs to the regular watch URL so the WebView
    /// uses the standard player.
    static func normalizedURL(_ url: URL) -> URL {
        let path = url.path
        guard let prefix = ["/shorts/", "/live/"].first(where: { path.hasPrefix($0) }) else {
            return url
        }
        let videoID = String(path.dropFirst(prefix.count))
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

    /// The Mac's default desktop UA gets the desktop watch page, which the player scripts are
    /// not written for, so it borrows the iPhone UA to get the same mobile page as iOS.
    static var youTubeUserAgent: String? {
        #if os(macOS)
        return sakuraUserAgent
        #else
        return nil
        #endif
    }

    static func release(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelAutoplayKick()
        coordinator.releaseMessageHandlers(on: webView.configuration.userContentController)
        // Leave the WKWebView alive if the session still owns it so audio
        // continues while collapsed into the tab bar bottom accessory.
    }
}

#if os(macOS)
extension YouTubePlayerWebView: NSViewRepresentable {

    func makeNSView(context: Context) -> YouTubePlayerContainerView {
        YouTubePlayerContainerView(webView: makeWebView(coordinator: context.coordinator))
    }

    func updateNSView(_ nsView: YouTubePlayerContainerView, context: Context) {}

    static func dismantleNSView(_ nsView: YouTubePlayerContainerView, coordinator: Coordinator) {
        release(nsView.webView, coordinator: coordinator)
    }
}

/// WebKit's video fullscreen moves the web view into its own window, and
/// SwiftUI would keep resizing it to the inline frame if it were the
/// representable's view, so SwiftUI only lays out this container.
final class YouTubePlayerContainerView: NSView {

    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = bounds
        webView.autoresizingMask = [.width, .height]
        addSubview(webView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#else
extension YouTubePlayerWebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        makeWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        release(uiView, coordinator: coordinator)
    }
}
#endif
