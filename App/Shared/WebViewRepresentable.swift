import SwiftUI
import WebKit

#if os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#else
typealias PlatformViewRepresentable = UIViewRepresentable
#endif

/// A `WKWebView` wrapped for SwiftUI on both iOS and macOS, which name their
/// representable requirements differently.
protocol WebViewRepresentable: PlatformViewRepresentable {
    func makeWebView(context: Context) -> WKWebView
    func updateWebView(_ webView: WKWebView, context: Context)
}

extension WebViewRepresentable {

    func updateWebView(_ webView: WKWebView, context: Context) {}

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        updateWebView(nsView, context: context)
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        updateWebView(uiView, context: context)
    }
    #endif
}
