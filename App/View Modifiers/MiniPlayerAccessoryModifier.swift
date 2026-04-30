import SwiftUI

struct MiniPlayerAccessoryModifier: ViewModifier {

    let audioPlayer: AudioPlayer
    let youTubeSession: YouTubePlayerSession
    @Binding var presentedPodcastArticle: Article?
    @Binding var presentedYouTubeArticle: Article?
    var miniPlayerTransition: Namespace.ID

    func body(content: Content) -> some View {
        if audioPlayer.currentArticleID != nil {
            content
                .tabViewBottomAccessory {
                    MiniPlayerView(
                        transitionID: "miniPlayer",
                        transitionNamespace: miniPlayerTransition
                    ) { article in
                        presentedPodcastArticle = article
                    }
                }
        } else if youTubeSession.currentArticle != nil {
            content
                .tabViewBottomAccessory {
                    YouTubeMiniPlayerView(
                        transitionID: "youTubeMiniPlayer",
                        transitionNamespace: miniPlayerTransition
                    ) { article in
                        presentedYouTubeArticle = article
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func miniPlayerAccessory(
        audioPlayer: AudioPlayer,
        youTubeSession: YouTubePlayerSession,
        presentedPodcastArticle: Binding<Article?>,
        presentedYouTubeArticle: Binding<Article?>,
        transition: Namespace.ID
    ) -> some View {
        modifier(MiniPlayerAccessoryModifier(
            audioPlayer: audioPlayer,
            youTubeSession: youTubeSession,
            presentedPodcastArticle: presentedPodcastArticle,
            presentedYouTubeArticle: presentedYouTubeArticle,
            miniPlayerTransition: transition
        ))
    }
}
