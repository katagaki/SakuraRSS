import FoundationModels
import SwiftUI
import Hanami

extension NewYouTubePlayerView {

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var descriptionSource: String? {
        if let summary = article.summary, !summary.isEmpty { return summary }
        if let content = article.content, !content.isEmpty { return content }
        if article.isEphemeral, let fetched = fetchedMetadata?.description, !fetched.isEmpty {
            return fetched
        }
        return nil
    }

    var displayTitle: String {
        if article.isEphemeral, let title = fetchedMetadata?.title, !title.isEmpty {
            return title
        }
        return article.title
    }

    var hasDescription: Bool {
        guard let descriptionSource else { return false }
        return !descriptionSource.isEmpty
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil || hasCachedTranslation
    }

    var displayDescription: String? {
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return descriptionSource
    }

    var youtubeAppURL: URL? {
        guard let url = URL(string: article.url),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "youtube"
        return components.url
    }

    @ViewBuilder
    func ephemeralUploaderRow(metadata: YouTubeVideoMetadata) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.uploader)
                    .font(.subheadline.bold())
                if let publishDate = metadata.publishDate {
                    Text(publishDate, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let raw = metadata.publishDateString, !raw.isEmpty {
                    Text(raw)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    var feedAvatarView: some View {
        if let icon {
            IconImage(icon, size: 36, circle: true, skipInset: true)
        } else if let acronymIcon {
            IconImage(acronymIcon, size: 36, circle: true, skipInset: true)
        } else if let feed {
            InitialsAvatarView(feed.title, size: 36, circle: true)
        } else {
            Circle()
                .fill(.secondary.opacity(0.2))
                .frame(width: 36, height: 36)
        }
    }
}
