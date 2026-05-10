import Foundation

public enum RedditExtractionOutcome {
    case handled
    case linkedArticle(URL)
    case none
}

public extension ContentResolver {

    func tryRedditExtraction() async -> RedditExtractionOutcome {
        let isRedditCandidate = feed?.isRedditFeed == true
            || (article.isEphemeral && URL(string: article.url).map { Self.isRedditPostURL($0) } == true)
        guard isRedditCandidate else { return .none }
        do {
            let redditResult = try await RedditProvider.shared.fetchContent(for: article)
            switch redditResult {
            case .markerString(let markerString):
                if !markerString.isEmpty {
                    result.text = markerString
                    persistCachedContent(markerString)
                    return .handled
                }
                return .none
            case .linkedArticle(let linkedURL):
                return .linkedArticle(linkedURL)
            }
        } catch {
            log("Extract", "Reddit fetch failed, falling through: \(error)")
            return .none
        }
    }

    func tryHackerNewsExtraction() async -> Bool {
        let isHackerNewsCandidate = feed?.isHackerNewsFeed == true || article.isEphemeral
        guard isHackerNewsCandidate,
              let url = URL(string: article.url),
              HackerNewsPostFetcher.isSelfPostURL(url) else { return false }
        do {
            if let html = try await HackerNewsPostFetcher.fetchPostText(for: url) {
                let text = HTMLContentExtractor.extractText(
                    fromHTML: html,
                    baseURL: url,
                    excludeTitle: article.title
                )
                if let text, !text.isEmpty {
                    result.text = text
                    persistCachedContent(text)
                    return true
                }
            }
        } catch {
            log("Extract", "HN post fetch failed, falling through: \(error)")
        }
        return false
    }

    func tryProviderExtraction() async -> Bool {
        if tryArXivExtraction() { return true }
        if tryInstagramExtraction() { return true }
        if await tryXPostExtraction() { return true }
        return await tryWebViewExtractor()
    }

    private func tryArXivExtraction() -> Bool {
        guard let url = URL(string: article.url), ArXivProvider.isAbstractURL(url) else { return false }
        if let summary = article.summary, !summary.isEmpty {
            result.text = summary
            persistCachedContent(summary)
        }
        return true
    }

    private func tryInstagramExtraction() -> Bool {
        guard article.isInstagramPostURL else { return false }
        let text = renderInstagramPostContent()
        result.text = text
        if !text.isEmpty {
            persistCachedContent(text)
        }
        return true
    }

    private func tryXPostExtraction() async -> Bool {
        guard article.isXPostURL,
              UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds"),
              let url = URL(string: article.url),
              let tweetID = XProvider.extractTweetID(from: url),
              XProvider.hasSession() else { return false }
        let fetcher = XProvider()
        if let content = await fetcher.fetchTweetContent(tweetID: tweetID) {
            applyXTweetContent(content)
            return true
        }
        log("Extract", "X post fetch failed, falling through: \(article.url)")
        return false
    }

    private func applyXTweetContent(_ content: ParsedTweetContent) {
        let text = renderXTweetContent(content)
        result.text = text
        if result.metadata.author == nil {
            let displayName = content.focal.author.isEmpty
                ? "@\(content.focal.authorHandle)"
                : content.focal.author
            if !displayName.isEmpty {
                result.metadata.author = displayName
            }
        }
        if result.metadata.publishedDate == nil, let date = content.focal.publishedDate {
            result.metadata.publishedDate = date
        }
        if !text.isEmpty {
            persistCachedContent(text)
        }
    }

    private func tryWebViewExtractor() async -> Bool {
        guard let url = URL(string: article.url),
              let extractor = SiteContentExtractorRegistry.extractor(for: url),
              extractor.requiresWebView else { return false }
        let text = await extractViaWebView(from: url, excludeTitle: article.title)
        result.text = text
        if let text, !text.isEmpty {
            persistCachedContent(text)
        }
        return true
    }
}
