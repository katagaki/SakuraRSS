import SwiftUI

struct TodayQuickAccessVisibilityBadge: View {

    let isVisible: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.thinMaterial)
                .overlay {
                    Circle().strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            if isVisible {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor.gradient)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 24, height: 24)
    }
}
