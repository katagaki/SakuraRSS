import SwiftUI
import UIKit

extension View {
    /// Presents an iOS popover with no arrow, anchored to this view.
    func arrowlessPopover<PopoverContent: View>(
        isPresented: Binding<Bool>,
        preferredSize: CGSize = CGSize(width: 280, height: 250),
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        background(
            ArrowlessPopoverPresenter(
                isPresented: isPresented,
                preferredSize: preferredSize,
                content: content
            )
        )
    }
}

private struct ArrowlessPopoverPresenter<Content: View>: UIViewControllerRepresentable {

    @Binding var isPresented: Bool
    let preferredSize: CGSize
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isPresented = $isPresented
        let presented = uiViewController.presentedViewController as? UIHostingController<Content>
        if isPresented {
            if let presented {
                presented.rootView = content()
            } else {
                let host = UIHostingController(rootView: content())
                host.modalPresentationStyle = .popover
                host.preferredContentSize = preferredSize
                host.view.backgroundColor = .clear
                if let popover = host.popoverPresentationController {
                    popover.permittedArrowDirections = []
                    popover.sourceView = uiViewController.view
                    popover.sourceRect = CGRect(
                        x: uiViewController.view.bounds.midX,
                        y: uiViewController.view.bounds.maxY,
                        width: 0,
                        height: 0
                    )
                    popover.delegate = context.coordinator
                }
                uiViewController.present(host, animated: true)
            }
        } else if presented != nil {
            uiViewController.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    final class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
        var isPresented: Binding<Bool>

        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }

        func adaptivePresentationStyle(
            for controller: UIPresentationController,
            traitCollection: UITraitCollection
        ) -> UIModalPresentationStyle {
            .none
        }

        func presentationControllerDidDismiss(
            _ presentationController: UIPresentationController
        ) {
            isPresented.wrappedValue = false
        }
    }
}
