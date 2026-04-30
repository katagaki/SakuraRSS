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
                    MiniPlayerView { article in
                        presentedPodcastArticle = article
                    }
                    .matchedTransitionSource(id: "miniPlayer", in: miniPlayerTransition)
                }
        } else if youTubeSession.currentArticle != nil {
            content
                .tabViewBottomAccessory {
                    YouTubeMiniPlayerView { article in
                        presentedYouTubeArticle = article
                    }
                    .matchedTransitionSource(id: "youTubeMiniPlayer", in: miniPlayerTransition)
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
