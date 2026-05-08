import SwiftUI
import FoundationModels

extension PodcastEpisodeView {

    var isOffline: Bool {
        !networkMonitor.isOnline
    }

    var downloadProgress: DownloadProgress? {
        downloadManager.activeDownloads[article.id]
    }

    var canPlay: Bool {
        isDownloaded || !isOffline
    }

    var canDownload: Bool {
        !isDownloaded && !isOffline && downloadProgress == nil
    }

    var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var hasTranslationForCurrentMode: Bool {
        if showingSummary {
            return translatedSummary != nil
        }
        return translatedText != nil
    }

    var displayText: String? {
        guard let summary = article.summary, !summary.isEmpty else { return nil }
        if showingSummary, let summarizedText {
            if showingTranslation, let translatedSummary {
                return translatedSummary
            }
            return summarizedText
        }
        if showingTranslation, let translatedText {
            return translatedText
        }
        return summary
    }

    var isThisEpisode: Bool {
        audioPlayer.currentArticleID == article.id
    }

    func initializeEpisode() async {
        feedManager.markRead(article)
        if let feed = feedManager.feed(forArticle: article) {
            feedName = feed.title
            if let data = feed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            icon = await IconCache.shared.icon(for: feed)
        }
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }
        if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id),
           let text = cached.text, !text.isEmpty {
            translatedText = text
        }
        isDownloaded = downloadManager.isDownloaded(articleID: article.id)
        if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
           !cached.isEmpty {
            transcript = cached
        }
    }
}
