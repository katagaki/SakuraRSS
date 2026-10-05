import SwiftUI
import Hanami
#if !os(visionOS)
@preconcurrency import Translation
#endif

extension ArticleDetailView {

    @ToolbarContentBuilder
    var articleToolbar: some ToolbarContent {
        if !previewMode, !article.isEphemeral,
           UIDevice.current.userInterfaceIdiom != .pad,
           let feed = feedManager.feed(forArticle: article) {
            ToolbarItem(placement: .topBarLeading) {
                feedToolbarIcon
                    .contentShape(.rect)
                    .onTapGesture {
                        navigateToFeed?(feed)
                    }
            }
            #if !os(visionOS)
            .sharedBackgroundVisibility(.hidden)
            #endif
        }
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

    @ViewBuilder
    private var feedToolbarIcon: some View {
        if let icon {
            IconImage(icon, size: 36, cornerRadius: 8,
                      circle: isVideoFeed, skipInset: skipIconInset)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 36, cornerRadius: 8,
                      circle: isVideoFeed, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 36, circle: isVideoFeed, cornerRadius: 8)
        }
    }

    func loadArticleMetadata() async {
        isBookmarked = feedManager.isBookmarked(article)
        if !article.isEphemeral, !previewMode, marksReadOnAppear {
            feedManager.markRead(article)
        }
        let feed = feedManager.feed(forArticle: article)
        if let feed {
            feedName = feed.title
            if let data = feed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            isVideoFeed = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
            skipIconInset = feed.isVideoFeed || feed.isXFeed || feed.isInstagramFeed
        }
        // Alongside the extraction, not ahead of it: an icon that is not cached
        // yet is a network round trip, and holds the content back behind it.
        async let iconLoad: Void = loadFeedIcon(feed)
        await extractArticleContent()
        Task { await resolveLinkedArticleURL() }
        if !article.isEphemeral {
            await loadCachedTranslationAndSummary()
        }
        loadInsightsInBackground()
        loadConversationInBackground()
        await iconLoad
    }

    private func loadFeedIcon(_ feed: Feed?) async {
        guard let feed else { return }
        icon = await Iconography.shared.icon(for: feed)
    }

    private func loadCachedTranslationAndSummary() async {
        let articleID = article.id
        let (translation, summary) = await Task.detached(priority: .userInitiated) {
            (
                try? DatabaseManager.shared.cachedArticleTranslation(for: articleID),
                try? DatabaseManager.shared.cachedArticleSummary(for: articleID)
            )
        }.value
        if let translation {
            translatedTitle = translation.title
            translatedText = translation.text
            translatedSummary = translation.summary
            hasCachedTranslation = translation.title != nil || translation.text != nil
            showingTranslation = hasCachedTranslation
        }
        if let summary, !summary.isEmpty {
            hasCachedSummary = true
        }
    }

}
