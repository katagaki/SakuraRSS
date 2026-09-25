import SwiftUI

#if !os(visionOS)
/// Keeps the swipe-back gestures working with the navigation bar hidden.
/// `UINavigationController` disables its own recognisers when the bar goes
/// away, so they are taken back over: both the edge swipe and the
/// swipe-from-anywhere that iOS 26 adds beside it.
struct InteractivePopGestureEnabler: UIViewRepresentable {

    let onBegin: () -> Void
    let onEnd: (_ cancelled: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onBegin = onBegin
        context.coordinator.onEnd = onEnd
        // Deferred: the view is not in the hierarchy yet on the first pass, so
        // there is no navigation controller to find.
        DispatchQueue.main.async {
            guard let controller = uiView.enclosingNavigationController else { return }
            context.coordinator.adopt(controller)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        weak var navigationController: UINavigationController?
        var onBegin: (() -> Void)?
        var onEnd: ((Bool) -> Void)?
        private var observedRecognizers: [ObjectIdentifier: UIGestureRecognizer] = [:]

        /// The edge swipe is the recogniser UIKit hands out by name; the
        /// swipe-from-anywhere iOS 26 adds is an unnamed sibling on the
        /// controller's own view, so it is found by walking them all.
        func adopt(_ controller: UINavigationController) {
            navigationController = controller
            var recognizers = controller.view.gestureRecognizers ?? []
            if let edge = controller.interactivePopGestureRecognizer, !recognizers.contains(edge) {
                recognizers.append(edge)
            }
            for recognizer in recognizers where recognizer is UIPanGestureRecognizer {
                recognizer.isEnabled = true
                recognizer.delegate = self
                observe(recognizer)
            }
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
                onBegin?()
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
                onEnd?(wasCancelled)
                return
            }
            coordinator.animate(alongsideTransition: nil) { [weak self] context in
                self?.onEnd?(context.isCancelled)
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

public extension View {
    /// Keeps swipe-back working under a hidden navigation bar, and tells the
    /// store while one is in flight so its chrome holds still until the
    /// swipe is committed or cancelled.
    func interactivePopGesture<Root, Identity>(
        for store: TabNavigationStore<Root, Identity>
    ) -> some View {
        interactivePopGesture(
            onBegin: { store.beginInteractivePop() },
            onEnd: { store.endInteractivePop(cancelled: $0) }
        )
    }

    @ViewBuilder
    func interactivePopGesture(
        onBegin: @escaping () -> Void,
        onEnd: @escaping (_ cancelled: Bool) -> Void
    ) -> some View {
        #if os(visionOS)
        self
        #else
        background {
            InteractivePopGestureEnabler(onBegin: onBegin, onEnd: onEnd)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #endif
    }
}
