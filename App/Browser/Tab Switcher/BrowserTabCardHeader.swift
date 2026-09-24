import SwiftUI
import Hanami

/// The card's title row, laid over the top of the preview.
struct BrowserTabCardHeader: View {

    let description: BrowserLocationDescription
    let canClose: Bool
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            BrowserLocationLabel(
                description: description,
                iconSize: 16,
                titleFont: .caption.weight(.medium),
                showsSubtitle: false
            )
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            Spacer(minLength: 0)
            if canClose {
                closeButton
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        // Light glyphs and glass whatever the system appearance: the row
        // always sits on the dark end of the gradient.
        .environment(\.colorScheme, .dark)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .frame(width: 14, height: 14)
        }
        .compatibleGlassButtonStyle()
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .accessibilityLabel(String(localized: "Menu.CloseTab", table: "Browser"))
    }
}
