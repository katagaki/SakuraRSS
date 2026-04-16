import SwiftUI
import WebKit

/// `UIViewRepresentable` wrapping a `WKWebView` that injects a
/// tap-to-identify overlay into fetched HTML.
///
/// Every element tap produces a `PickedElement` sent back via
/// `onElementPicked`.  Navigation is blocked so tapping links
/// doesn't leave the picker.
struct PetalElementPickerWebView: UIViewRepresentable {

    let html: String
    let baseURL: URL?
    let onElementPicked: (PickedElement) -> Void

    /// Metadata the JS overlay sends back when the user taps.
    struct PickedElement {
        let selector: String
        let text: String
        let tag: String
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onElementPicked: onElementPicked)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "elementPicked")
        controller.addUserScript(WKUserScript(
            source: Self.injectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsLinkPreview = false
        webView.loadHTMLString(html, baseURL: baseURL)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "elementPicked")
    }
}

// MARK: - Coordinator

extension PetalElementPickerWebView {

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        let onElementPicked: (PickedElement) -> Void

        init(onElementPicked: @escaping (PickedElement) -> Void) {
            self.onElementPicked = onElementPicked
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "elementPicked",
                  let body = message.body as? [String: Any],
                  let selector = body["selector"] as? String,
                  !selector.isEmpty else { return }
            let element = PickedElement(
                selector: selector,
                text: body["text"] as? String ?? "",
                tag: body["tag"] as? String ?? ""
            )
            DispatchQueue.main.async { self.onElementPicked(element) }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(action.navigationType == .linkActivated ? .cancel : .allow)
        }
    }
}

// MARK: - Injection script

private extension PetalElementPickerWebView {

    /// JavaScript injected at document-end.  Adds a touch-highlight
    /// and sends a compact CSS selector back to Swift when the user
    /// taps any element.
    static let injectionJS = #"""
    (function () {
      var style = document.createElement('style');
      style.textContent =
        '*, *::before, *::after {' +
        '  -webkit-tap-highlight-color: transparent !important;' +
        '  -webkit-touch-callout: none !important;' +
        '  -webkit-user-select: none !important;' +
        '  user-select: none !important;' +
        '  pointer-events: auto !important;' +
        '}' +
        '.petal-tap { outline: 3px solid rgba(255,59,48,0.8) !important;' +
        '             background-color: rgba(255,59,48,0.08) !important; }';
      document.head.appendChild(style);

      document.addEventListener('contextmenu', function (e) {
        e.preventDefault();
      }, true);

      function cssEscape(v) {
        return (typeof CSS !== 'undefined' && CSS.escape)
          ? CSS.escape(v) : v.replace(/([^\w-])/g, '\\$1');
      }

      function compact(el) {
        var tag = el.tagName.toLowerCase();
        var id = el.getAttribute('id');
        if (id) return '#' + cssEscape(id);
        var cls = null;
        el.classList.forEach(function (c) {
          if (!cls && c.indexOf('petal-') !== 0) cls = c;
        });
        return cls ? tag + '.' + cls : tag;
      }

      var selected = null;

      document.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopImmediatePropagation();
        var el = e.target;
        if (!el || el === document.body || el === document.documentElement) return;

        // Drill into a child when tapping the already-selected element.
        if (selected && el === selected) {
          var stack = document.elementsFromPoint(e.clientX, e.clientY);
          for (var i = 0; i < stack.length; i++) {
            if (selected.contains(stack[i]) && stack[i] !== selected) {
              el = stack[i];
              break;
            }
          }
          if (el === selected) return;
        }

        if (selected) selected.classList.remove('petal-tap');
        selected = el;
        el.classList.add('petal-tap');
        var text = (el.innerText || el.textContent || '').trim()
          .replace(/\s+/g, ' ').substring(0, 100);
        window.webkit.messageHandlers.elementPicked.postMessage({
          selector: compact(el),
          text: text,
          tag: el.tagName.toLowerCase()
        });
      }, true);
    })();
    """#
}
