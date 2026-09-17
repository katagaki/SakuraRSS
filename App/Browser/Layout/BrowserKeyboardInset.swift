import SwiftUI

/// Insets the browser shell by the keyboard itself.
///
/// The compact chrome is a real `.bottomBar` so it keeps the system's glass
/// and its morph, but on device that bar does not lift above the keyboard:
/// the page inside it does, while the bar stays at the screen's bottom edge
/// with the address field under the keys. So the shell drops the system's
/// keyboard safe area and pads by the keyboard's own height instead, which
/// moves the bar with it.
struct BrowserKeyboardInset: ViewModifier {

    @State private var height: CGFloat = 0
    @State private var duration: Double = 0.25

    private var willChangeFrame: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
    }

    private var willHide: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
    }

    func body(content: Content) -> some View {
        content
            // Padding first, then drop the region: the other way round the
            // padded view still sits inside the system's keyboard inset and
            // the shell is shortened twice.
            .padding(.bottom, height)
            .ignoresSafeArea(.keyboard)
            .animation(.easeOut(duration: duration), value: height)
            .onReceive(willChangeFrame) { notification in
                apply(notification)
            }
            .onReceive(willHide) { notification in
                readDuration(from: notification)
                height = 0
            }
    }

    private func apply(_ notification: Notification) {
        readDuration(from: notification)
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = Self.activeWindow else { return }
        // Converted into the app's own window: the notification's frame is in
        // screen space, and the tallest connected scene is not always the one
        // the browser is in.
        let overlap = window.bounds.maxY - window.convert(frame, from: nil).minY
        // Less the home indicator: the bar keeps its own bottom inset inside
        // the shortened shell, which would otherwise show as a gap between
        // the field and the keys.
        height = max(0, min(overlap - window.safeAreaInsets.bottom, window.bounds.height))
    }

    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }

    private func readDuration(from notification: Notification) {
        if let value = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
           value > 0 {
            duration = value
        }
    }
}

extension View {
    func browserKeyboardInset() -> some View {
        modifier(BrowserKeyboardInset())
    }
}
