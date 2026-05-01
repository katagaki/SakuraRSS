import SwiftUI

struct InsecureBannerView: View {

    let articleURL: String
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: articleURL) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(String(localized: "Article.Insecure.Banner", table: "Articles"))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(.red.opacity(colorScheme == .dark ? 0.35 : 0.85)).interactive(),
            in: .capsule
        )
        .foregroundStyle(.white)
    }
}
