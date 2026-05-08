import SwiftUI

extension YouTubePlayerView {

    func initializePlayerSession() async {
        activateBackgroundAudioSession()
        isBookmarked = feedManager.isBookmarked(article)
        session.adopt(article: article)
        isPlaying = session.isPlaying
        if session.isPlaying || session.duration > 0 {
            hasStartedPlaying = true
        }
        let signedIn = await YouTubePlayerView.hasYouTubeSession()
        let premium = signedIn ? await YouTubePlayerView.hasYouTubePremium() : false
        isPiPEligible = signedIn && premium

        if let loadedFeed = feedManager.feed(forArticle: article) {
            feed = loadedFeed
            session.channelTitle = loadedFeed.title
            if let data = loadedFeed.acronymIcon {
                acronymIcon = UIImage(data: data)
            }
            icon = await IconCache.shared.icon(for: loadedFeed)
        }
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
                .map(String.init)
            sponsorSegments = await SponsorBlockClient.fetchSegments(
                for: videoID, categories: categories
            )
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
}
