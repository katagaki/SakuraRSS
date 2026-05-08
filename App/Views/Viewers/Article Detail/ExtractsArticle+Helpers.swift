import Foundation

extension ExtractsArticle {

    /// Applies extracted metadata without clobbering values already supplied by the feed.
    func applyMetadata(_ metadata: ArticleMetadata) {
        if article.author == nil, let author = metadata.author {
            extractedAuthor = author
        }
        if article.publishedDate == nil, let date = metadata.publishedDate {
            extractedPublishedDate = date
        }
        if article.imageURL == nil, let lead = metadata.leadImageURL {
            extractedLeadImageURL = lead
        }
        if let pageTitle = metadata.pageTitle {
            extractedPageTitle = pageTitle
        }
    }

    /// Raw HTTP fetch returning decoded HTML and the response for header signals.
    func fetchHTML(from url: URL) async -> (String?, URLResponse?) {
        do {
            let request = URLRequest.sakura(url: url)
            let (data, response) = try await URLSession.shared.data(for: request)
            return (HTMLDataDecoder.decode(data, response: response), response)
        } catch {
            return (nil, nil)
        }
    }

    func extractViaWebView(from url: URL, excludeTitle: String?) async -> String? {
        let extractor = WebViewExtractor()
        return await extractor.extractText(from: url)
    }

    static func isRedditPostURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(),
              host == "reddit.com" || host.hasSuffix(".reddit.com") else { return false }
        return RedditProvider.postID(from: url) != nil
    }
}
