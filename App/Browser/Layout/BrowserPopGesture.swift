import SwiftUI

#if !os(visionOS)
/// Keeps the swipe-back gesture working with the navigation bar hidden.
/// `UINavigationController` disables its own recogniser when the bar goes away,
/// so the browser takes the recogniser back over.
struct BrowserPopGestureEnabler: UIViewRepresentable {

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
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        weak var navigationController: UINavigationController?

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
    func browserPopGestureEnabled() -> some View {
        #if os(visionOS)
        self
        #else
        background {
            BrowserPopGestureEnabler()
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #endif
    }
}
