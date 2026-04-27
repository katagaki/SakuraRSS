import SwiftUI
import WebKit

/// Presents an article URL through archive.today in an embedded WebView.
struct ArchivePhView: View {

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
            ArchivePhWebView(
                url: url,
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
    }
}

private func archivePhURL(for articleURL: URL) -> URL? {
    URL(string: "https://archive.md/\(articleURL.absoluteString)")
}

private struct ArchivePhWebView: UIViewRepresentable {

    let url: URL
    let reloadTrigger: Int
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = sakuraUserAgent
        context.coordinator.lastReloadTrigger = reloadTrigger
        if let target = archivePhURL(for: url) {
            webView.load(URLRequest(url: target))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if reloadTrigger != context.coordinator.lastReloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            Task { @MainActor in
                isLoading = true
            }
            if let target = archivePhURL(for: url) {
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
