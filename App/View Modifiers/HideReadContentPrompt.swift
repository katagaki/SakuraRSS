import SwiftUI

struct HideReadContentPrompt: ViewModifier {
    let isVisible: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ZStack {
                    if isVisible {
                        HideReadContentButton(action: action)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            .transition(
                                .move(edge: .bottom)
                                    .combined(with: .opacity)
                            )
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.smooth.speed(2.0), value: isVisible)
            }
    }
}

extension View {
    func hideReadContentPrompt(
        isVisible: Bool,
        action: @escaping () -> Void
    ) -> some View {
        modifier(HideReadContentPrompt(isVisible: isVisible, action: action))
    }
}
