import SwiftUI

struct EmbedBlockView: View {

    let provider: EmbedProvider
    let url: URL
    /// Routes the tap so the parent can honour the user's
    /// `Reading.LinkOpenMode`. Falls back to the system browser when nil.
    var onTap: ((URL) -> Void)?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let onTap {
                onTap(url)
            } else {
                openURL(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: provider.symbolName)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(url.absoluteString)
                        .font(.footnote)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
