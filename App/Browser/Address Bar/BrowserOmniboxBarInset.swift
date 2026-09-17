import SwiftUI

/// Keeps the editing bar on the line the bottom bar's glass occupies: 8pt
/// above the keyboard while it is up, and otherwise 28pt above the window's
/// bottom edge, which is where a `.bottomBar` item's glass sits.
struct BrowserOmniboxBarInset: ViewModifier {

    static let gapAboveKeyboard: CGFloat = 8
    static let gapAboveWindowBottom: CGFloat = 28

    @State private var isKeyboardUp = false

    func body(content: Content) -> some View {
        content
            .padding(.bottom, isKeyboardUp ? BrowserOmniboxBarInset.gapAboveKeyboard : restingInset)
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            ) { _ in
                isKeyboardUp = true
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                isKeyboardUp = false
            }
    }

    /// The bar already sits above the home indicator, so only the remainder is
    /// padding, and it is a negative number on a device that has one.
    private var restingInset: CGFloat {
        min(
            BrowserOmniboxBarInset.gapAboveKeyboard,
            BrowserOmniboxBarInset.gapAboveWindowBottom - BrowserDeviceMetrics.safeAreaInsets.bottom
        )
    }
}

extension View {
    func browserOmniboxBarInset() -> some View {
        modifier(BrowserOmniboxBarInset())
    }
}
