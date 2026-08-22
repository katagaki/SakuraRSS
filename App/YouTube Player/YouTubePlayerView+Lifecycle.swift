import SwiftUI
import Hanami

extension YouTubePlayerView {

    func initializePlayerSession() async {
        prepareBackgroundAudioSession()
        isBookmarked = feedManager.isBookmarked(article)
        session.adopt(article: article)
        isPlaying = session.isPlaying
        if session.isPlaying || session.duration > 0 {
            hasStartedPlaying = true
        }
        if session.isPlaying || session.duration > 0 || session.webView != nil {
            isPlayerReady = true
        }
        if let loadedFeed = feedManager.feed(forArticle: article) {
            feed = loadedFeed
            session.channelTitle = loadedFeed.title
            if let data = loadedFeed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            icon = await Iconography.shared.icon(for: loadedFeed)
        }
        loadResumePlaybackTime()
        session.videoTitle = article.title
        if let imageURL = article.imageURL.flatMap(URL.init(string:)) {
            session.artworkURL = imageURL
        }

        if article.isEphemeral {
            await fetchYouTubeOEmbed()
        }

        if sponsorBlockEnabled,
           let videoID = SponsorBlockClient.extractVideoID(from: article.url) {
            let categories = sponsorBlockCategories
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let fetched = await SponsorBlockClient.fetchSegments(
                for: videoID, categories: categories
            )
            sponsorSegments = Self.mergedSegments(fetched)
        }

        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
            if cached.text != nil { hasCachedTranslation = true }
            translatedText = cached.text
        }
        if !article.isEphemeral,
           let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }
    }

    private func loadResumePlaybackTime() {
        guard session.currentTime <= 0, !session.isPlaying,
              let videoID = SponsorBlockClient.extractVideoID(from: article.url) else { return }
        resumePlaybackTime = YouTubePlaybackPositionStore.position(forVideoID: videoID)
    }

    func restorePlaybackPositionIfNeeded() {
        guard let resumePlaybackTime else { return }
        self.resumePlaybackTime = nil
        seek(to: resumePlaybackTime)
        lastCheckedPlaybackTime = resumePlaybackTime
    }
}
