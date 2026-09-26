import SwiftUI

struct BotChallengeBannerView: View {

    let onVerify: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onVerify) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                Text(String(localized: "Article.BotChallenge.Banner", table: "Articles"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(alignment: .leading)
        }
        .buttonStyle(.plain)
        .compatibleGlassEffect(
            in: .capsule,
            tint: .blue.opacity(colorScheme == .dark ? 0.35 : 0.85),
            interactive: true
        )
        .foregroundStyle(.white)
    }
}
