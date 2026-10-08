import SwiftUI

extension View {

    /// Runs `action` when Escape is pressed in a macOS sheet that has no
    /// cancel button; does nothing on iOS.
    func onEscape(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        background {
            // macOS only routes Escape to a button with the cancel action shortcut.
            Button("", action: action)
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        #else
        self
        #endif
    }
}
