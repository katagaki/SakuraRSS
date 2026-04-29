import SwiftUI

struct MiniPlayerAccessoryModifier: ViewModifier {

    let audioPlayer: AudioPlayer
    @Binding var miniPlayerPresentedArticle: Article?
    var miniPlayerTransition: Namespace.ID

    func body(content: Content) -> some View {
        if audioPlayer.currentArticleID != nil {
            content
                .tabViewBottomAccessory {
                    MiniPlayerView { article in
                        miniPlayerPresentedArticle = article
                    }
                    .matchedTransitionSource(id: "miniPlayer", in: miniPlayerTransition)
                }
        } else {
            content
        }
    }
}

extension View {
    func miniPlayerAccessory(
        audioPlayer: AudioPlayer,
        presentedArticle: Binding<Article?>,
        transition: Namespace.ID
    ) -> some View {
        modifier(MiniPlayerAccessoryModifier(
            audioPlayer: audioPlayer,
            miniPlayerPresentedArticle: presentedArticle,
            miniPlayerTransition: transition
        ))
    }
}
