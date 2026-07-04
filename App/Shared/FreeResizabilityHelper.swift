#if targetEnvironment(macCatalyst)
import SwiftUI

struct FreeResizabilityHelper: UIViewRepresentable {
    func makeUIView(context: Context) -> ResizabilityView { ResizabilityView() }
    func updateUIView(_ uiView: ResizabilityView, context: Context) {
        uiView.applyRestrictions()
    }

    class ResizabilityView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyRestrictions()
            DispatchQueue.main.async { [weak self] in
                self?.applyRestrictions()
            }
        }

        func applyRestrictions() {
            guard let restrictions = window?.windowScene?.sizeRestrictions else { return }
            restrictions.minimumSize = CGSize(width: 400, height: 300)
            restrictions.maximumSize = CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }
}
#endif
