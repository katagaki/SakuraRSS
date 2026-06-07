import SwiftUI

struct MarkAllReadPill: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(
                String(localized: "MarkAllRead", table: "Articles"),
                systemImage: "envelope.open"
            )
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .compatibleGlassEffect(in: .capsule, interactive: true)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}
