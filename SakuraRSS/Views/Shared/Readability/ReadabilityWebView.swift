import SwiftUI
import WebKit

struct ReadabilityWebView: UIViewRepresentable {

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

        let library = WKUserScript(
            source: ReadabilityScript.bundledLibrary,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(library)
        config.userContentController.add(
            context.coordinator,
            name: ReadabilityScript.messageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = sakuraUserAgent
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.lastReloadTrigger = reloadTrigger
        webView.load(URLRequest(url: url))
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
            webView.load(URLRequest(url: url))
        }
    }
}
