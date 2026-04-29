import SwiftUI

struct RefreshPromptOverlay: ViewModifier {
    let isVisible: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack {
                    if isVisible {
                        RefreshPromptButton(action: action)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .transition(
                                .move(edge: .top)
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
    func refreshPromptOverlay(
        isVisible: Bool,
        action: @escaping () -> Void
    ) -> some View {
        modifier(RefreshPromptOverlay(isVisible: isVisible, action: action))
    }
}
