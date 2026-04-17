import SwiftUI
import WebKit

/// `UIViewRepresentable` wrapping a `WKWebView` that injects a
/// tap-to-identify overlay into fetched HTML.
///
/// Every element tap produces a `PickedElement` (the selected
/// element plus its ancestor chain and visible direct children)
/// sent back via `onElementPicked`.  Navigation is blocked so
/// tapping links doesn't leave the picker.
struct PetalElementPickerWebView: UIViewRepresentable {

    let html: String
    let baseURL: URL?
    let controller: PetalElementPickerController
    let onElementPicked: (PickedElement) -> Void

    /// A single element's summary (selector + preview text + tag).
    struct ElementInfo: Hashable, Sendable {
        let selector: String
        let text: String
        let tag: String
    }

    /// The full payload the JS overlay sends back when a tap or
    /// breadcrumb/child navigation changes the selection.
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
