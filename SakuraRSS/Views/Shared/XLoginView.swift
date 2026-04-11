import SwiftUI
import WebKit

/// A web view that presents the X (Twitter) login page.
/// Session cookies persist in the default WKWebsiteDataStore so that
/// XProfileScraper can use them for authenticated profile scraping.
struct XLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isCheckingLogin = false
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            XLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("XLogin.Title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
                .onChange(of: isLoggedIn) { _, loggedIn in
                    if loggedIn {
                        dismiss()
                    }
                }
        }
    }
}

/// UIViewRepresentable wrapper for a WKWebView that loads the X login page.
private struct XLoginWebView: UIViewRepresentable {

    @Binding var isLoggedIn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoggedIn: $isLoggedIn)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = sakuraUserAgent

        if let loginURL = URL(string: "https://x.com/i/flow/login") {
            webView.load(URLRequest(url: loginURL))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoggedIn: Bool
        private var checkTask: Task<Void, Never>?

        init(isLoggedIn: Binding<Bool>) {
            _isLoggedIn = isLoggedIn
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !isLoggedIn else { return }
            checkTask?.cancel()
            checkTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }

                let loggedIn = await XProfileScraper.hasXSession()
                if loggedIn {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
