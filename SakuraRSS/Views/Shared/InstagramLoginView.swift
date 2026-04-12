import SwiftUI
import WebKit

/// A web view that presents the Instagram login page.
/// Session cookies persist in the default WKWebsiteDataStore so that
/// InstagramProfileScraper can use them for authenticated profile scraping.
struct InstagramLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            InstagramLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("InstagramLogin.Title")
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

/// UIViewRepresentable wrapper for a WKWebView that loads the Instagram login page.
private struct InstagramLoginWebView: UIViewRepresentable {

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

        if let loginURL = URL(string: "https://www.instagram.com/accounts/login/") {
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

                // Copy any cookies Instagram just set in the WKWebView
                // over to Keychain so `hasInstagramSession()`, which
                // reads from Keychain, can detect the successful login.
                await InstagramProfileScraper.syncCookiesFromWebKit()

                let loggedIn = await InstagramProfileScraper.hasInstagramSession()
                if loggedIn {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
