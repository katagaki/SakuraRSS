import SwiftUI

extension NewYouTubePlayerView {

    #if !os(visionOS)
    func handleOrientationChange() {
        let orientation = UIDevice.current.orientation
        if orientation.isLandscape {
            if !isFullscreenPresented {
                isFullscreenPresented = true
            }
        } else if orientation.isPortrait {
            if isFullscreenPresented {
                isFullscreenPresented = false
            }
        }
    }
    #endif

    func loadStream() async {
        isBookmarked = feedManager.isBookmarked(article)
        await loadFeedAndIcon()
        await loadSponsorSegmentsIfNeeded()
        loadCachedTranslationsAndSummaries()

        guard let videoId = NewYouTubeClient.parseVideoIdentifier(article.url) else {
            loadState = .failed
            return
        }

        if playback.currentVideoID == videoId, playback.player != nil {
            playback.updateMetadata(
                title: article.title,
                artist: feed?.title,
                artworkURLString: article.imageURL
            )
            loadState = .ready
            return
        }

        do {
            let client = try await NewYouTubeClient.bootstrap()
            let manifestURL = try await client.hlsPlaylistURL(videoId: videoId)
            playback.load(
                url: manifestURL,
                videoID: videoId,
                title: article.title,
                artist: feed?.title,
                artworkURLString: article.imageURL
            )
            loadState = .ready
        } catch {
            log("YT NewPlayer", "Failed to resolve stream: \(error)")
            loadState = .failed
        }
    }

    func loadFeedAndIcon() async {
        guard let loadedFeed = feedManager.feed(forArticle: article) else { return }
        feed = loadedFeed
        if let data = loadedFeed.acronymIcon {
            acronymIcon = UIImage(data: data)
        }
        icon = await IconCache.shared.icon(for: loadedFeed)
    }

    func loadSponsorSegmentsIfNeeded() async {
        guard sponsorBlockEnabled,
              let videoID = SponsorBlockClient.extractVideoID(from: article.url) else {
            return
        }
        let categories = sponsorBlockCategories
            .split(separator: ",")
            .map(String.init)
        sponsorSegments = await SponsorBlockClient.fetchSegments(
            for: videoID, categories: categories
        )
    }

    func loadCachedTranslationsAndSummaries() {
        guard !article.isEphemeral else { return }
        if let cached = try? DatabaseManager.shared.cachedArticleTranslation(for: article.id) {
            if cached.text != nil { hasCachedTranslation = true }
            translatedText = cached.text
        }
        if let cached = try? DatabaseManager.shared.cachedArticleSummary(for: article.id),
           !cached.isEmpty {
            hasCachedSummary = true
        }
    }
}
