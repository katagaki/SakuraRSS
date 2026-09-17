import SwiftUI

#if !os(visionOS)
/// Keeps the swipe-back gestures working with the navigation bar hidden.
/// `UINavigationController` disables its own recognisers when the bar goes
/// away, so the browser takes them back over: both the edge swipe and the
/// swipe-from-anywhere that iOS 26 adds beside it.
struct BrowserPopGestureEnabler: UIViewRepresentable {

    let store: BrowserTabStore

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Deferred: the view is not in the hierarchy yet on the first pass, so
        // there is no navigation controller to find.
        DispatchQueue.main.async {
            guard let controller = uiView.enclosingNavigationController else { return }
            context.coordinator.adopt(controller, store: store)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        weak var navigationController: UINavigationController?
        private var observedRecognizers: [ObjectIdentifier: UIGestureRecognizer] = [:]
        private var store: BrowserTabStore?

        /// The edge swipe is the recogniser UIKit hands out by name; the
        /// swipe-from-anywhere iOS 26 adds is an unnamed sibling on the
        /// controller's own view, so it is found by walking them all.
        func adopt(_ controller: UINavigationController, store: BrowserTabStore) {
            navigationController = controller
            self.store = store
            var recognizers = controller.view.gestureRecognizers ?? []
            if let edge = controller.interactivePopGestureRecognizer, !recognizers.contains(edge) {
                recognizers.append(edge)
            }
            for recognizer in recognizers where Self.isPopRecognizer(recognizer) {
                recognizer.isEnabled = true
                recognizer.delegate = self
                observe(recognizer)
            }
        }

        private static func isPopRecognizer(_ recognizer: UIGestureRecognizer) -> Bool {
            recognizer is UIPanGestureRecognizer
        }

        private func observe(_ recognizer: UIGestureRecognizer) {
            let key = ObjectIdentifier(recognizer)
            guard observedRecognizers[key] == nil else { return }
            observedRecognizers[key] = recognizer
            recognizer.addTarget(self, action: #selector(handlePop(_:)))
        }

        @objc private func handlePop(_ recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began:
                store?.beginInteractivePop()
            case .ended, .cancelled, .failed:
                finishPop(wasCancelled: recognizer.state != .ended)
            default:
                break
            }
        }

        /// The recogniser ends before the stack finishes moving, and its own
        /// state does not say whether the pop was committed: only the
        /// transition coordinator knows, and only once the snap back or
        /// forward has played out.
        private func finishPop(wasCancelled: Bool) {
            guard let coordinator = navigationController?.transitionCoordinator else {
                store?.endInteractivePop(cancelled: wasCancelled)
                return
            }
            coordinator.animate(alongsideTransition: nil) { [weak self] context in
                self?.store?.endInteractivePop(cancelled: context.isCancelled)
            }
        }

        /// Without this the gesture also fires at the root, which leaves the
        /// stack wedged.
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }

        /// The swipe-from-anywhere sits over the page's own scroll views, so
        /// it has to share with them; the edge swipe keeps to itself.
        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            !(recognizer is UIScreenEdgePanGestureRecognizer)
        }
    }
}

private extension UIView {
    var enclosingNavigationController: UINavigationController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UINavigationController { return controller }
            responder = current.next
        }
        return nil
    }
}
#endif

extension View {
    @ViewBuilder
    func browserPopGestureEnabled(store: BrowserTabStore) -> some View {
        #if os(visionOS)
        self
        #else
        background {
            BrowserPopGestureEnabler(store: store)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #endif
    }
}
