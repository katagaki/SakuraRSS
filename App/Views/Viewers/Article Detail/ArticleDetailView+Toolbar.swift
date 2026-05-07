import SwiftUI
#if !os(visionOS)
@preconcurrency import Translation
#endif

extension ArticleDetailView {

    @ToolbarContentBuilder
    var articleToolbar: some ToolbarContent {
        if !previewMode {
            ToolbarItem(placement: .principal) {
                if let activityLabel = toolbarActivityLabel {
                    ToolbarActivityIndicator(label: activityLabel)
                } else {
                    Spacer()
                }
            }
        }
        if !previewMode {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadArticleToolbar
            } else {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    articleOpenToolbarItems
                    if !article.isEphemeral {
                        Button {
                            isBookmarked.toggle()
                            feedManager.toggleBookmark(article)
                        } label: {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        }
                    }
                    if !isInsecureArticle {
                        articleOverflowMenu
                    }
                }
            }
        }
    }

    var toolbarActivityLabel: String? {
        if isTranslating {
            return String(localized: "Article.Translating", table: "Articles")
        }
        if isSummarizing {
            return String(localized: "Article.Summarizing", table: "Articles")
        }
        return nil
    }

    func loadArticleMetadata() async {
        isBookmarked = feedManager.isBookmarked(article)
        if !article.isEphemeral, !previewMode, marksReadOnAppear {
            feedManager.markRead(article)
        }
        if let feed = feedManager.feed(forArticle: article) {
            feedName = feed.title
            if let data = feed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            isVideoFeed = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
            skipIconInset = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
            icon = await IconCache.shared.icon(for: feed)
        }
        await extractArticleContent()
        Task { await resolveLinkedArticleURL() }
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
        loadConversationInBackground()
    }

}
