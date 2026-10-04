import Hanami
import SwiftUI

struct PodcastEpisodeNotes: View {

    let article: Article

    private var blocks: [IdentifiedContentBlock] {
        let text = article.summary ?? ""
        return text.isEmpty ? [] : ContentBlock.cachedIdentifiedBlocks(text)
    }

    var body: some View {
        let blocks = blocks
        if !blocks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                ForEach(blocks) { identified in
                    ContentBlockView(block: identified.block)
                }
            }
        }
    }
}
