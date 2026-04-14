import SwiftUI
import WebKit

/// Presents an article URL through the clearthis.page reader service in an
/// embedded WebView. The service strips ads and clutter and reformats the
/// page for distraction-free reading.
struct ClearThisPageView: View {

    @Environment(\.colorScheme) private var colorScheme
    let url: URL
    @State private var isLoading = true
    @State private var pageTitle: String = ""
    @State private var reloadTrigger = 0

    var body: some View {
        ZStack {
            ClearThisPageWebView(
                url: url,
                colorScheme: colorScheme,
                reloadTrigger: reloadTrigger,
                isLoading: $isLoading,
                pageTitle: $pageTitle
            )
            .ignoresSafeArea()
            .opacity(isLoading ? 0 : 1)

            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle(pageTitle.isEmpty
            ? String(localized: "ClearThisPage.Title")
            : pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reloadTrigger &+= 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
}

/// Builds a clearthis.page URL that wraps the supplied article URL.
/// Uses `URLComponents` so the article URL is properly percent-encoded
/// without manual string interpolation.
private func clearThisPageURL(for articleURL: URL) -> URL? {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "clearthis.page"
    components.path = "/"
    components.queryItems = [
        URLQueryItem(name: "u", value: articleURL.absoluteString)
    ]
    return components.url
}

/// User script injected at document start. clearthis.page uses
/// `dark-mode-switch.min.js`, which reads `localStorage['darkSwitch']`
/// to decide whether to add `data-theme="dark"` to the `<body>` and check
/// the `#darkSwitch` checkbox. This script seeds that storage value from
/// the system color scheme (`prefers-color-scheme`), reapplies the body
/// attribute itself for safety, hides the manual `.topbar` toggle since
/// theme selection is automatic, and stays in sync if the system
/// appearance changes while the WebView is open.
private let clearThisPageThemeScript = """
(function() {
  function isDark() {
    return window.matchMedia
      && window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function syncStorage() {
    try {
      if (isDark()) {
        localStorage.setItem('darkSwitch', 'dark');
      } else {
        localStorage.removeItem('darkSwitch');
      }
    } catch (e) {}
  }
  function applyBodyAttribute() {
    if (!document.body) { return; }
    if (isDark()) {
      document.body.setAttribute('data-theme', 'dark');
    } else {
      document.body.removeAttribute('data-theme');
    }
    var sw = document.getElementById('darkSwitch');
    if (sw) { sw.checked = isDark(); }
  }
  function hideToggle() {
    var topbar = document.querySelector('.topbar');
    if (topbar && topbar.parentNode) {
      topbar.parentNode.removeChild(topbar);
    }
  }
  function applyAll() {
    syncStorage();
    applyBodyAttribute();
    hideToggle();
  }
  // Seed storage immediately so the page's own dark-mode-switch script
  // picks up the right value as soon as it runs.
  syncStorage();
  if (document.readyState !== 'loading') {
    applyAll();
  } else {
    document.addEventListener('DOMContentLoaded', applyAll);
  }
  window.addEventListener('load', applyAll);
  // React to system appearance changes while the WebView is open.
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var listener = function() { applyAll(); };
    if (mq.addEventListener) {
      mq.addEventListener('change', listener);
    } else if (mq.addListener) {
      mq.addListener(listener);
    }
  }
})();
"""

private struct ClearThisPageWebView: UIViewRepresentable {

    let url: URL
    let colorScheme: ColorScheme
    let reloadTrigger: Int
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, pageTitle: $pageTitle)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let themeScript = WKUserScript(
            source: clearThisPageThemeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(themeScript)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = sakuraUserAgent
        webView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.lastReloadTrigger = reloadTrigger
        if let target = clearThisPageURL(for: url) {
            webView.load(URLRequest(url: target))
        }
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
            if let target = clearThisPageURL(for: url) {
                webView.load(URLRequest(url: target))
            }
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String
        var lastReloadTrigger: Int = 0

        init(isLoading: Binding<Bool>, pageTitle: Binding<String>) {
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        /// Only allow HTTPS navigations. Cancels cleartext HTTP, app-scheme
        /// links, and other potentially unsafe URL schemes that could be
        /// triggered from the rendered page.
        func webView(
            _: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.request.url?.scheme?.lowercased() == "https" else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            Task { @MainActor in
                isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            let resolvedTitle = webView.title
            Task { @MainActor in
                isLoading = false
                if let resolvedTitle, !resolvedTitle.isEmpty {
                    pageTitle = resolvedTitle
                }
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!,
                     withError _: Error) {
            Task { @MainActor in
                isLoading = false
            }
        }
    }
}
