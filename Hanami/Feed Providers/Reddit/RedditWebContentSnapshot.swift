import Foundation

nonisolated struct RedditWebContentSnapshot: Decodable, Sendable {
    let found: Bool
    let challenge: Bool
    let bodyHTML: String
    let imageURLs: [String]
    let videoURL: String?
    let linkedURL: String?

    func postResult(baseURL: URL) async -> RedditPostFetchResult {
        if let linkedURL, let url = URL(string: linkedURL),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            return .linkedArticle(url)
        }
        var blocks: [String] = []
        if let body = await HTMLContentExtractor.extractText(
            offMainActorFromHTML: bodyHTML, baseURL: baseURL
        ), !body.isEmpty {
            blocks.append(body)
        }
        if let videoURL {
            blocks.append("{{VIDEO}}\(videoURL){{/VIDEO}}")
        } else {
            for imageURL in imageURLs where !blocks.contains(where: { $0.contains(imageURL) }) {
                blocks.append("{{IMG}}\(imageURL){{/IMG}}")
            }
        }
        return .markerString(blocks.joined(separator: "\n\n"))
    }
}
