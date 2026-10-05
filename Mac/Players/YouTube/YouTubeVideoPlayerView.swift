import Hanami
import SwiftUI
import WebKit

/// What the reader shows for a YouTube video: the shared player's web view
/// with native controls, built on the same session and scripts as iOS.
struct YouTubeVideoPlayerView: View {

    let article: Article
    let feed: Feed?
    private let session = YouTubePlayerSession.shared
    private let pictureInPicture = YouTubePictureInPicture.shared

    @State private var isPlaying = false
    @State private var webView: WKWebView?
    @State private var isAd = false
    @State private var isAdSkippable = false
    @State private var advertiserURL: URL?
    @State private var videoAspectRatio = YouTubePlayerSession.shared.videoAspectRatio
    @State private var isPiP = false
    @State private var isPlayerReady = false
    @State private var chapters: [YouTubeChapter] = []
    @State private var resumePosition: TimeInterval?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                videoArea
                YouTubeVideoControls(
                    session: session,
                    isPlaying: isPlaying,
                    webView: webView,
                    chapters: chapters,
                    videoURL: URL(string: article.url)
                )
                YouTubeVideoDetails(article: article, feed: feed)
            }
            .padding(24)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: prepareSession)
        .onChange(of: isPlaying) { _, playing in
            session.isPlaying = playing
        }
        .onChange(of: videoAspectRatio) { _, ratio in
            session.videoAspectRatio = ratio
        }
        .onDisappear {
            // The next video's view can appear before this one disappears, and
            // by then the session belongs to it.
            guard session.holds(article) else { return }
            pictureInPicture.exit(session: session, returningToContent: false)
            session.stop()
        }
        .onChange(of: isPlayerReady) { _, isReady in
            guard isReady, let resumePosition else { return }
            self.resumePosition = nil
            YouTubePlaybackCommands.seek(webView, to: resumePosition)
        }
    }

    private var videoArea: some View {
        YouTubePlayerWebView(
            urlString: article.url,
            session: session,
            isPlaying: $isPlaying,
            webView: $webView,
            isAd: $isAd,
            isAdSkippable: $isAdSkippable,
            advertiserURL: $advertiserURL,
            videoAspectRatio: $videoAspectRatio,
            isPiP: $isPiP,
            isPlayerReady: $isPlayerReady,
            chapters: $chapters,
            onTimeUpdate: { [session] time in session.currentTime = time },
            onDurationUpdate: { [session] duration in session.duration = duration }
        )
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(.black)
        .clipShape(.rect(cornerRadius: 12))
        // Takes the mouse instead of the page, as iOS blocks touches to it,
        // so YouTube's player can't hide the pointer or react on its own.
        .overlay {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) {
                    pictureInPicture.exit(session: session, returningToContent: true)
                    YouTubePlaybackCommands.enterFullscreen(webView)
                }
                .onTapGesture { session.togglePlayPause() }
        }
        .overlay {
            YouTubeVideoOverlays(
                isAd: isAd,
                isAdSkippable: isAdSkippable,
                isPiP: isPiP || pictureInPicture.isActive,
                onSkipAd: { YouTubePlaybackCommands.skipAd(webView) },
                onReturnFromPiP: { pictureInPicture.exit(session: session, returningToContent: true) }
            )
        }
    }

    private func prepareSession() {
        session.adopt(article: article)
        session.videoTitle = article.title
        session.channelTitle = feed?.title
        session.artworkURL = article.imageURL.flatMap(URL.init(string:))
        if session.currentTime <= 0, let videoID = SponsorBlockClient.extractVideoID(from: article.url) {
            resumePosition = YouTubePlaybackPositionStore.position(forVideoID: videoID)
        }
    }
}
