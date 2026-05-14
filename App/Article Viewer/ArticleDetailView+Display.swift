import SwiftUI
import FoundationModels
import Hanami

extension ArticleDetailView {

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    var hasTranslatedFullText: Bool {
        translatedText != nil || hasCachedTranslation
    }

    var fullTextHasImages: Bool {
        extractedText?.contains("{{IMG}}") == true
    }

    var isInsecureArticle: Bool {
        URL(string: article.url)?.scheme?.lowercased() == "http"
    }

    var displayText: String? {
        if isInsecureArticle {
            return String(localized: "Article.Insecure.Content", table: "Articles")
        }
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return extractedText ?? article.summary
    }

    /// Subtitle for non-ephemeral articles. iPad keeps the feed icon and name
    /// (tappable to open the feed); compact widths drop them since the feed
    /// identity is already shown in the principal capsule.
    @ViewBuilder
    var articleSubtitleRow: some View {
        let feed = feedManager.feed(forArticle: article)
        let feedTitle = feed?.title
        let resolvedAuthor = subtitleResolvedAuthor(feedTitle: feedTitle)
        let resolvedDate = article.publishedDate ?? extractedPublishedDate

        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadSubtitleRow(
                feed: feed,
                feedTitle: feedTitle,
                author: resolvedAuthor,
                date: resolvedDate
            )
        } else {
            compactSubtitleRow(author: resolvedAuthor, date: resolvedDate)
        }
    }

    private func subtitleResolvedAuthor(feedTitle: String?) -> String? {
        guard let author = article.author ?? extractedAuthor else { return nil }
        if author.caseInsensitiveCompare(feedTitle ?? "") == .orderedSame { return nil }
        return author
    }

    @ViewBuilder
    private func iPadSubtitleRow(
        feed: Feed?, feedTitle: String?, author: String?, date: Date?
    ) -> some View {
        HStack(spacing: 12) {
            feedAvatarView
            if let feedTitle {
                Text(feedTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let author {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let date {
                Text("·")
                    .foregroundStyle(.tertiary)
                RelativeTimeText(date: date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private func compactSubtitleRow(author: String?, date: Date?) -> some View {
        if author != nil || date != nil {
            HStack(spacing: 12) {
                if let author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if author != nil, date != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let date {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder
    private var feedAvatarView: some View {
        if let icon {
            IconImage(icon, size: 18, cornerRadius: 3,
                      circle: isVideoFeed, skipInset: skipIconInset)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 18, cornerRadius: 3,
                      circle: isVideoFeed, skipInset: true)
        } else if let feedName {
            InitialsAvatarView(feedName, size: 18, circle: isVideoFeed, cornerRadius: 3)
        }
    }

    /// Domain host extracted from the article URL, used as a fallback
    /// metadata label when the article is ephemeral (e.g. opened via an
    /// in-article link tap) and no feed/author info is available.
    var ephemeralDomainName: String? {
        guard let host = URL(string: article.url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Domain + author + relative-time row for ephemeral articles opened
    /// from in-article links. Shows the link's domain name in place of the
    /// missing feed/author info.
    @ViewBuilder
    var ephemeralLinkMetadataRow: some View {
        let domain = ephemeralDomainName
        let author = article.author ?? extractedAuthor
        let date = article.publishedDate ?? extractedPublishedDate
        if domain != nil || author != nil || date != nil {
            HStack(spacing: 12) {
                if let domain {
                    Text(domain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if domain != nil, author != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if domain != nil || author != nil, date != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let date {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
    }

    /// Author + relative-time row for ephemeral X posts (share-extension
    /// opens). Mirrors the non-ephemeral row but skips the feed icon/title
    /// since there's no feed lookup, and avoids leading separators.
    @ViewBuilder
    var ephemeralXMetadataRow: some View {
        let author = article.author ?? extractedAuthor
        let date = article.publishedDate ?? extractedPublishedDate
        if author != nil || date != nil {
            HStack(spacing: 12) {
                if let author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if author != nil, date != nil {
                    Text("·")
                        .foregroundStyle(.tertiary)
                }
                if let date {
                    RelativeTimeText(date: date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
        }
    }

    var displayTitle: String {
        if isInsecureArticle {
            return String(localized: "Article.Insecure.Title", table: "Articles")
        }
        if let translated = showingTranslation ? translatedTitle : nil {
            return translated
        }
        if article.isXPostURL {
            return String(localized: "Article.XPost.Title", table: "Articles")
        }
        if article.isInstagramPostURL {
            return String(localized: "Article.InstagramPost.Title", table: "Articles")
        }
        if article.isBlueskyPostURL {
            return String(localized: "Article.BlueskyPost.Title", table: "Articles")
        }
        if article.isEphemeral {
            if let extractedPageTitle {
                return extractedPageTitle
            }
            return String(localized: "Article.LoadingContent", table: "Articles")
        }
        return article.title
    }
}
