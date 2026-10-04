import Hanami
import SwiftUI

struct ContentBlockView: View {

    let block: ContentBlock

    var body: some View {
        switch block {
        case .text(let text):
            Text(LocalizedStringKey(text))
                .font(.system(size: 15))
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .image(let url, _):
            RemoteImage(url: url)
        case .code(let code):
            ScrollView(.horizontal) {
                Text(code)
                    .font(.system(size: 12.5, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(.quinary, in: .rect(cornerRadius: 8))
        case .table(let header, let rows):
            ContentTableView(header: header, rows: rows)
        case .definitionList(let items):
            DefinitionListView(items: items)
        case .math(let latex):
            Text(latex)
                .font(.system(size: 14, design: .serif))
                .italic()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .video(let url, _, _), .audio(let url), .xPost(let url), .embed(_, let url):
            ExternalContentLink(url: url)
        case .youtube(let videoID):
            ExternalContentLink(url: URL(string: "https://www.youtube.com/watch?v=\(videoID)"))
        }
    }
}
