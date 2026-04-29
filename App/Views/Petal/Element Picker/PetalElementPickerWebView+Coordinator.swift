import WebKit

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
                  let selected = Self.element(from: body["selected"])
            else { return }
            let ancestors = (body["ancestors"] as? [Any] ?? []).compactMap(Self.element(from:))
            let children = (body["children"] as? [Any] ?? []).compactMap(Self.element(from:))
            let picked = PickedElement(
                selected: selected,
                ancestors: ancestors,
                children: children
            )
            DispatchQueue.main.async { self.onElementPicked(picked) }
        }

        private static func element(from raw: Any?) -> ElementInfo? {
            guard let dict = raw as? [String: Any],
                  let selector = dict["selector"] as? String,
                  !selector.isEmpty
            else { return nil }
            return ElementInfo(
                selector: selector,
                text: dict["text"] as? String ?? "",
                tag: dict["tag"] as? String ?? ""
            )
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
