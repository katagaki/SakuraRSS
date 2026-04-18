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
                    .foregroundStyle(.orange)
                Text(String(localized: "Article.Paywall.Banner", table: "Articles"))
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
