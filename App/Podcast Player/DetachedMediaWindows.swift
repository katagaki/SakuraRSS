#if os(visionOS) || targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct DetachedYouTubePlayerWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64?

    @State private var session = YouTubePlayerSession()

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                YouTubePlayerView(
                    article: article,
                    session: session,
                    showsDismissButton: false
                )
            }
            .compatibleSoftScrollEdgeEffectStyle()
            .onDisappear {
                session.clear()
            }
            #if targetEnvironment(macCatalyst)
            .background {
                FreeResizabilityHelper()
                    .frame(width: 0, height: 0)
            }
            .stopsMediaOnWindowClose {
                session.clear()
            }
            #endif
        } else {
            ProgressView()
        }
    }
}

struct DetachedPodcastPlayerWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64?

    @State private var audioPlayer = AudioPlayer()

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                PodcastEpisodeView(
                    article: article,
                    audioPlayer: audioPlayer,
                    showsDismissButton: false
                )
            }
            .compatibleSoftScrollEdgeEffectStyle()
            .onDisappear {
                audioPlayer.stop()
            }
            #if targetEnvironment(macCatalyst)
            .background {
                FreeResizabilityHelper()
                    .frame(width: 0, height: 0)
            }
            .stopsMediaOnWindowClose {
                audioPlayer.stop()
            }
            #endif
        } else {
            ProgressView()
        }
    }
}

#endif
