import SwiftUI
import WebKit
import Hanami

/// Web view presenting the YouTube/Google login page; cookies persist for authenticated playback.
struct YouTubeLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            YouTubeLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(String(localized: "YouTubeLogin.Title", table: "Integrations"))
                .inlineNavigationTitle()
                .compatibleSoftScrollEdgeEffectStyle()
                .toolbar {
                    ToolbarItem(placement: .sheetTrailing) {
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

private struct YouTubeLoginWebView: WebViewRepresentable {

    @Binding var isLoggedIn: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoggedIn: $isLoggedIn)
    }

    func makeWebView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = sakuraUserAgent
        // swiftlint:disable:next line_length
        if let loginURL = URL(string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https://m.youtube.com/") {
            webView.load(URLRequest(url: loginURL))
        }
        return webView
    }

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

                let loggedIn = await YouTubeWebSession.hasSession()
                if loggedIn {
                    self.isLoggedIn = true
                }
            }
        }
    }
}
