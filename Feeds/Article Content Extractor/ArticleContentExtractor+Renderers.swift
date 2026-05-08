import Foundation

extension ArticleContentExtractor {

    /// Builds the article body for an Instagram post: every carousel image
    /// stacked above the caption. Falls back to `article.imageURL` when the
    /// post is single-image (carousel array is empty in that case).
    func renderInstagramPostContent() -> String {
        let imageURLs = !article.carouselImageURLs.isEmpty
            ? article.carouselImageURLs
            : (article.imageURL.map { [$0] } ?? [])

        var sections: [String] = imageURLs.map { "{{IMG}}\($0){{/IMG}}" }
        let caption = (article.summary ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !caption.isEmpty {
            sections.append(ArticleMarker.escape(caption))
        }
        return sections.joined(separator: "\n\n")
    }

    func renderXTweetContent(_ content: ParsedTweetContent) -> String {
        var sections: [String] = []
        for item in content.threadItems {
            var section = ArticleMarker.escape(item.text)
            for imageURL in item.imageURLs {
                section += "\n\n{{IMG}}\(imageURL){{/IMG}}"
            }
            if let quoted = item.quotedTweetURL {
                section += "\n\n{{XPOST}}\(quoted){{/XPOST}}"
            }
            sections.append(section)
        }
        return sections.joined(separator: "\n\n")
    }
}
