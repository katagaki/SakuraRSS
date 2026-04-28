import SwiftUI
import WebKit

/// Web view presenting the Substack login page; cookies are synced to Keychain after sign-in.
struct SubstackLoginView: View {

    @Environment(\.dismiss) var dismiss
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            SubstackLoginWebView(isLoggedIn: $isLoggedIn)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(String(localized: "SubstackLogin.Title", table: "Integrations"))
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

private struct SubstackLoginWebView: UIViewRepresentable {

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

        if let loginURL = URL(string: "https://substack.com/sign-in?redirect=%2F") {
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
            guard let url = webView.url, isPostLoginRedirect(url) else { return }

            checkTask?.cancel()
            checkTask = Task { @MainActor in
                await SubstackAuth.syncCookiesFromWebKit()

                if SubstackAuth.hasSession() {
                    self.isLoggedIn = true
                }
            }
        }

        private func isPostLoginRedirect(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased(),
                  host == "substack.com" || host == "www.substack.com" else {
                return false
            }
            let path = url.path
            return path.isEmpty || path == "/"
        }
    }
}
