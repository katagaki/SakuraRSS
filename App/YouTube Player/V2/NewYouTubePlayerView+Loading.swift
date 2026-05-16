import SwiftUI
import Hanami

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
            log("YT NewPlayer", "Failed to parse videoId from url: \(article.url)")
            loadState = .failed
            return
        }
        log("YT NewPlayer", "loadStream videoId=\(videoId) url=\(article.url)")

        if playback.currentVideoID == videoId, playback.player != nil {
            await fetchMetadataIfNeeded(videoId: videoId)
            playback.updateMetadata(
                title: playbackTitle,
                artist: playbackArtist,
                artworkURLString: article.imageURL
            )
            loadState = .ready
            return
        }

        do {
            let client = try await NewYouTubeClient.bootstrap()
            async let manifestTask = client.hlsPlaylistURL(videoId: videoId)
            async let metadataTask = client.fetchVideoMetadata(videoId: videoId)
            fetchedMetadata = try? await metadataTask
            let manifestURL = try await manifestTask
            playback.load(
                url: manifestURL,
                videoID: videoId,
                title: playbackTitle,
                artist: playbackArtist,
                artworkURLString: article.imageURL
            )
            loadState = .ready
        } catch {
            log("YT NewPlayer", "Failed to resolve stream: \(error)")
            loadState = .failed
        }
    }

    private func fetchMetadataIfNeeded(videoId: String) async {
        guard fetchedMetadata == nil else { return }
        guard let client = try? await NewYouTubeClient.bootstrap() else { return }
        fetchedMetadata = try? await client.fetchVideoMetadata(videoId: videoId)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private var playbackTitle: String {
        if article.isEphemeral, let title = nonEmpty(fetchedMetadata?.title) {
            return title
        }
        return article.title
    }

    private var playbackArtist: String? {
        if article.isEphemeral, let artist = nonEmpty(fetchedMetadata?.uploader) {
            return artist
        }
        return feed?.title
    }

    func loadFeedAndIcon() async {
        guard let loadedFeed = feedManager.feed(forArticle: article) else { return }
        feed = loadedFeed
        if let data = loadedFeed.acronymIcon {
            acronymIcon = UIImage(data: data)
        }
        icon = await Iconography.shared.icon(for: loadedFeed)
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
