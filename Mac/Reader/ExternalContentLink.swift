import SwiftUI

/// Media the Mac reader can't play inline yet, kept as a link instead of
/// silently dropping it from the content.
struct ExternalContentLink: View {

    @Environment(\.openURL) private var openURL
    let url: URL?

    var body: some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.rectangle")
                    Text(url.host() ?? url.absoluteString)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.quinary, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}
