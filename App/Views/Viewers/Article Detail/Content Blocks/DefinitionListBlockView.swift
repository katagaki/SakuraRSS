import SwiftUI

struct DefinitionListBlockView: View {

    let items: [ContentBlock.DefinitionListItem]
    let textStyle: ContentBlockStack.TextStyle
    let imageNamespace: Namespace.ID
    let onImageTap: (URL) -> Void
    var onLinkTap: ((URL) -> Void)?

    private var termFont: UIFont {
        UIFont.preferredFont(forTextStyle: .callout).bold()
    }

    private var definitionFont: UIFont {
        UIFont.preferredFont(forTextStyle: .callout)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    if !item.term.isEmpty {
                        ContentBlockStack(
                            text: item.term,
                            textStyle: textStyle,
                            font: termFont,
                            imageNamespace: imageNamespace,
                            onImageTap: onImageTap,
                            onLinkTap: onLinkTap
                        )
                    }
                    ForEach(Array(item.definitions.enumerated()), id: \.offset) { _, definition in
                        ContentBlockStack(
                            text: definition,
                            textStyle: textStyle,
                            font: definitionFont,
                            imageNamespace: imageNamespace,
                            onImageTap: onImageTap,
                            onLinkTap: onLinkTap
                        )
                        .padding(.leading, 16)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.55), lineWidth: 1.5)
        )
    }
}
