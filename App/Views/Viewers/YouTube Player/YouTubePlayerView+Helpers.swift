import FoundationModels
import SwiftUI

extension YouTubePlayerView {

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var descriptionSource: String? {
        article.summary ?? article.content
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
