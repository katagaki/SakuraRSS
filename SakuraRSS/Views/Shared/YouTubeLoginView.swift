import SwiftUI
import WebKit

/// A web view that presents the YouTube/Google login page.
/// Session cookies persist in the default WKWebsiteDataStore so that
/// the YouTube player can use them for authenticated playback (e.g. PiP).
struct YouTubeLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            YouTubeLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(String(localized: "YouTubeLogin.Title", table: "Integrations"))
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

private struct YouTubeLoginWebView: UIViewRepresentable {

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
        if let loginURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/") {
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

                let loggedIn = await YouTubePlayerView.hasYouTubeSession()
                if loggedIn {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
