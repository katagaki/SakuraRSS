import SwiftUI

struct DebugLayout: ViewModifier {

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .overlay(
                Rectangle()
                    .stroke(Color.red.opacity(0.5), lineWidth: 3)
            )
            .overlay(
                Ellipse()
                    .stroke(Color.red.opacity(0.5), lineWidth: 3)
            )
        #else
        content
        #endif
    }
}

extension View {
    func debugLayout() -> some View {
        modifier(DebugLayout())
    }
}
