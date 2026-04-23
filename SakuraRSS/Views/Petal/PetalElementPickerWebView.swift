import SwiftUI
import WebKit

/// `WKWebView` with a tap-to-identify overlay; element taps emit `PickedElement`.
struct PetalElementPickerWebView: UIViewRepresentable {

    let html: String
    let baseURL: URL?
    let controller: PetalElementPickerController
    let onElementPicked: (PickedElement) -> Void

    struct ElementInfo: Hashable, Sendable {
        let selector: String
        let text: String
        let tag: String
    }

    struct PickedElement {
        let selected: ElementInfo
        /// Immediate parent first, root-most ancestor last.
        let ancestors: [ElementInfo]
        /// Direct visible children of `selected`, in DOM order.
        let children: [ElementInfo]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onElementPicked: onElementPicked)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "elementPicked")
        userController.addUserScript(WKUserScript(
            source: Self.injectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = userController
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.loadHTMLString(html, baseURL: baseURL)
        controller.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        controller.webView = uiView
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "elementPicked")
    }
}
