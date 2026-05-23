#if os(visionOS) || targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct DetachedYouTubePlayerWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64?

    #if targetEnvironment(macCatalyst)
    @State private var session = YouTubePlayerSession()
    #endif

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                #if targetEnvironment(macCatalyst)
                YouTubePlayerView(
                    article: article,
                    session: session,
                    showsDismissButton: false
                )
                #else
                YouTubePlayerView(article: article, showsDismissButton: false)
                #endif
            }
            #if targetEnvironment(macCatalyst)
            .background {
                FreeResizabilityHelper()
                    .frame(width: 0, height: 0)
            }
            .onDisappear {
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

    #if targetEnvironment(macCatalyst)
    @State private var audioPlayer = AudioPlayer()
    #endif

    var body: some View {
        if let articleID, let article = feedManager.article(byID: articleID) {
            NavigationStack {
                #if targetEnvironment(macCatalyst)
                PodcastEpisodeView(
                    article: article,
                    audioPlayer: audioPlayer,
                    showsDismissButton: false
                )
                #else
                PodcastEpisodeView(article: article, showsDismissButton: false)
                #endif
            }
            #if targetEnvironment(macCatalyst)
            .background {
                FreeResizabilityHelper()
                    .frame(width: 0, height: 0)
            }
            .onDisappear {
                audioPlayer.stop()
            }
            #endif
        } else {
            ProgressView()
        }
    }
}

#if targetEnvironment(macCatalyst)
private struct FreeResizabilityHelper: UIViewRepresentable {
    func makeUIView(context: Context) -> ResizabilityView { ResizabilityView() }
    func updateUIView(_ uiView: ResizabilityView, context: Context) {
        uiView.applyRestrictions()
    }

    class ResizabilityView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyRestrictions()
            DispatchQueue.main.async { [weak self] in
                self?.applyRestrictions()
            }
        }

        func applyRestrictions() {
            guard let restrictions = window?.windowScene?.sizeRestrictions else { return }
            restrictions.minimumSize = CGSize(width: 400, height: 300)
            restrictions.maximumSize = CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }
}
#endif
#endif
