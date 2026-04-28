import SwiftUI

struct PaywallBannerView: View {

    let articleURL: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = URL(string: articleURL) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                Text(String(localized: "Article.Paywall.Banner", table: "Articles"))
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "safari")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(.orange.opacity(0.3)).interactive(),
            in: .rect(cornerRadius: 16)
        )
        .padding(.horizontal, 16)
    }
}
