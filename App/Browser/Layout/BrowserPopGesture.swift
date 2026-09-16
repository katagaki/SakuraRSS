import SwiftUI

#if !os(visionOS)
/// Keeps the swipe-back gesture working with the navigation bar hidden.
/// `UINavigationController` disables its own recogniser when the bar goes away,
/// so the browser takes the recogniser back over.
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
            context.coordinator.navigationController = controller
            controller.interactivePopGestureRecognizer?.isEnabled = true
            controller.interactivePopGestureRecognizer?.delegate = context.coordinator
            context.coordinator.observe(controller.interactivePopGestureRecognizer, store: store)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        weak var navigationController: UINavigationController?
        private weak var observedRecognizer: UIGestureRecognizer?
        private var store: BrowserTabStore?

        func observe(_ recognizer: UIGestureRecognizer?, store: BrowserTabStore) {
            self.store = store
            guard let recognizer, observedRecognizer !== recognizer else { return }
            observedRecognizer = recognizer
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

        func gestureRecognizer(
            _ recognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            false
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
