import SwiftUI
@preconcurrency import Translation

extension ArticleDetailView {

    var articleToolbar: some ToolbarContent {
        Group {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !article.isEphemeral {
                    Button {
                        isBookmarked.toggle()
                        feedManager.toggleBookmark(article)
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    }
                }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let shareURL = URL(string: article.url) {
                    ShareLink(item: shareURL) {
                        Label(String(localized: "Article.Share", table: "Articles"), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    func loadArticleMetadata() async {
        isBookmarked = article.isBookmarked
        if !article.isEphemeral {
            feedManager.markRead(article)
        }
        if let feed = feedManager.feed(forArticle: article) {
            feedName = feed.title
            if let data = feed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            isVideoFeed = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
            skipFaviconInset = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
                || FaviconNoInsetDomains.shouldUseFullImage(feedDomain: feed.domain)
            favicon = await FaviconCache.shared.favicon(for: feed)
        }
        await extractArticleContent()
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
            translatedTitle = cached.title
            translatedText = cached.text
            translatedSummary = cached.summary
            hasCachedTranslation = cached.title != nil || cached.text != nil
            showingTranslation = hasCachedTranslation
        }
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }
        loadInsightsInBackground()
    }

}
