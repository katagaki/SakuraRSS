import SwiftUI

/// Renders a sequence of `ContentBlock`s
struct ContentBlockStack: View {

    enum TextStyle {
        case primary
        case white
    }

    let text: String
    var textStyle: TextStyle = .primary
    let imageNamespace: Namespace.ID
    let onImageTap: (URL) -> Void
    var onLinkTap: ((URL) -> Void)?

    var body: some View {
        let blocks = ContentBlock.parse(text)
        ForEach(blocks) { block in
            switch block {
            case .text(let content):
                textView(content)
            case .code(let content):
                CodeBlockView(code: content)
            case .image(let url, let link):
                ImageBlockView(
                    url: url,
                    link: link,
                    namespace: imageNamespace
                ) {
                    onImageTap(url)
                }
            case .video(let url):
                VideoBlockView(url: url)
            case .audio(let url):
                AudioBlockView(url: url)
            case .youtube(let videoID):
                YouTubeEmbedBlockView(videoID: videoID)
            case .xPost(let url):
                XEmbedBlockView(url: url)
            case .embed(let provider, let url):
                EmbedBlockView(provider: provider, url: url)
            case .table(let header, let rows):
                TableBlockView(header: header, rows: rows)
            case .math(let latex):
                MathBlockView(latex: latex)
            }
        }
    }

    @ViewBuilder
    private func textView(_ content: String) -> some View {
        switch textStyle {
        case .primary:
            SelectableText(content, onLinkTap: onLinkTap)
        case .white:
            SelectableText(content, textColor: .white, onLinkTap: onLinkTap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
