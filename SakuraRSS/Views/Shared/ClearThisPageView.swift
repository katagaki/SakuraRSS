import SwiftUI
import WebKit

/// Presents an article URL through the clearthis.page reader service in an
/// embedded WebView. The service strips ads and clutter and reformats the
/// page for distraction-free reading.
struct ClearThisPageView: View {

    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var isLoading = true
    @State private var pageTitle: String = ""

    var body: some View {
        NavigationStack {
            ClearThisPageWebView(
                url: url,
                isLoading: $isLoading,
                pageTitle: $pageTitle
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(pageTitle.isEmpty
                ? String(localized: "ClearThisPage.Title")
                : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isLoading {
                        ProgressView()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Builds a clearthis.page URL that wraps the supplied article URL.
private func clearThisPageURL(for articleURL: URL) -> URL? {
    guard let encoded = articleURL.absoluteString
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        return nil
    }
    return URL(string: "https://clearthis.page/?u=\(encoded)")
}

private struct ClearThisPageWebView: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, pageTitle: $pageTitle)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = sakuraUserAgent
        if let target = clearThisPageURL(for: url) {
            webView.load(URLRequest(url: target))
        }
        return webView
    }

    func updateUIView(_: WKWebView, context _: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String

        init(isLoading: Binding<Bool>, pageTitle: Binding<String>) {
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        @MainActor
        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            isLoading = true
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            isLoading = false
            if let title = webView.title, !title.isEmpty {
                pageTitle = title
            }
        }

        @MainActor
        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            isLoading = false
        }

        @MainActor
        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!,
                     withError _: Error) {
            isLoading = false
        }
    }
}
