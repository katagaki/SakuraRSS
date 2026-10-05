import SwiftUI
import WebKit
import Hanami

/// Presents an article URL through clearthis.page in an embedded WebView.
struct ClearThisPageView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(FeedManager.self) private var feedManager
    let article: Article
    let url: URL
    @State private var isLoading = true
    @State private var reloadTrigger = 0
    @State private var isBookmarked: Bool

    init(article: Article, url: URL) {
        self.article = article
        self.url = url
        _isBookmarked = State(initialValue: article.isBookmarked)
    }

    var body: some View {
        ZStack {
            ClearThisPageWebView(
                url: url,
                colorScheme: colorScheme,
                reloadTrigger: reloadTrigger,
                isLoading: $isLoading
            )
            .ignoresSafeArea()
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            WebArticleViewerToolbar(
                article: article,
                url: url,
                isBookmarked: $isBookmarked,
                onReload: { reloadTrigger &+= 1 }
            )
        }
        .task(id: article.id) {
            if !article.isEphemeral {
                feedManager.markRead(article)
            }
        }
    }
}

private struct ClearThisPageWebView: UIViewRepresentable {

    let url: URL
    let colorScheme: ColorScheme
    let reloadTrigger: Int
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let themeScript = WKUserScript(
            source: ClearThisPageAddress.themeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(themeScript)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = sakuraUserAgent
        webView.pageZoom = 0.9
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.lastReloadTrigger = reloadTrigger
        if let target = ClearThisPageAddress.url(for: url) {
            webView.load(URLRequest(url: target))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let desired: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        if webView.overrideUserInterfaceStyle != desired {
            webView.overrideUserInterfaceStyle = desired
        }
        if reloadTrigger != context.coordinator.lastReloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            Task { @MainActor in
                isLoading = true
            }
            if let target = ClearThisPageAddress.url(for: url) {
                webView.load(URLRequest(url: target))
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var lastReloadTrigger: Int = 0

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        /// Only allows HTTPS navigations.
        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.request.url?.scheme?.lowercased() == "https" else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            Task { @MainActor in
                isLoading = true
            }
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            Task { @MainActor in
                isLoading = false
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!,
                     withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }
    }
}
