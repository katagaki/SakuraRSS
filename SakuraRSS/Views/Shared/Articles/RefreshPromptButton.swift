import SwiftUI

/// Capsule Liquid Glass button that appears at the top of an article list when
/// new content has arrived during a refresh. Tapping it releases the pending
/// articles into the visible list.
struct RefreshPromptButton: View {

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13.0, weight: .semibold))
                Text(String(localized: "Refresh.NewArticles", table: "Articles"))
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

private struct RefreshPromptOverlay: ViewModifier {
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
