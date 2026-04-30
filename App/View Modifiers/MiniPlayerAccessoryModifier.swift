import SwiftUI

struct MiniPlayerAccessoryModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    let audioPlayer: AudioPlayer
    let youTubeSession: YouTubePlayerSession
    let mediaPresenter: MediaPresenter
    @Namespace private var namespace

    func body(content: Content) -> some View {
        @Bindable var presenter = mediaPresenter
        let podcastSheetPresented = Binding<Bool>(
            get: { presenter.podcastArticle != nil },
            set: { if !$0 { presenter.podcastArticle = nil } }
        )
        let youTubeSheetPresented = Binding<Bool>(
            get: { presenter.youTubeArticle != nil },
            set: { if !$0 { presenter.youTubeArticle = nil } }
        )
        return content
            .tabViewBottomAccessory {
                if audioPlayer.currentArticleID != nil {
                    Button {
                        if let articleID = audioPlayer.currentArticleID,
                           let article = feedManager.article(byID: articleID) {
                            presenter.podcastArticle = article
                        }
                    } label: {
                        MiniPlayerBar()
                            .matchedTransitionSource(id: "miniPlayer", in: namespace)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                } else if youTubeSession.currentArticle != nil {
                    Button {
                        if let article = youTubeSession.currentArticle {
                            presenter.youTubeArticle = article
                        }
                    } label: {
                        YouTubeMiniPlayerBar()
                            .matchedTransitionSource(id: "youTubeMiniPlayer", in: namespace)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: podcastSheetPresented) {
                if let article = presenter.podcastArticle {
                    NavigationStack {
                        PodcastEpisodeView(article: article)
                            .environment(feedManager)
                    }
                    .navigationTransition(.zoom(sourceID: "miniPlayer", in: namespace))
                }
            }
            .sheet(isPresented: youTubeSheetPresented) {
                if let article = presenter.youTubeArticle {
                    NavigationStack {
                        YouTubePlayerView(article: article)
                            .environment(feedManager)
                    }
                    .navigationTransition(.zoom(sourceID: "youTubeMiniPlayer", in: namespace))
                }
            }
    }
}

extension View {
    func miniPlayerAccessory(
        audioPlayer: AudioPlayer,
        youTubeSession: YouTubePlayerSession,
        mediaPresenter: MediaPresenter
    ) -> some View {
        modifier(MiniPlayerAccessoryModifier(
            audioPlayer: audioPlayer,
            youTubeSession: youTubeSession,
            mediaPresenter: mediaPresenter
        ))
    }
}
