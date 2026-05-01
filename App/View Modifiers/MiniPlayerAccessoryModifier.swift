import SwiftUI

struct MiniPlayerAccessoryModifier: ViewModifier {

    @Environment(FeedManager.self) private var feedManager
    let audioPlayer: AudioPlayer
    let youTubeSession: YouTubePlayerSession
    let mediaPresenter: MediaPresenter

    /// `@State` ownership of the sheet binding is required for the matched
    /// zoom transition to anchor; an `@Observable` binding from the presenter
    /// breaks the transition. This must only be mutated by the accessory
    /// button itself. Any other writer (`.onChange`, presenter callback,
    /// etc.) breaks the matched transition.
    @State var isSheetPresented = false
    @Namespace var namespace

    /// What's currently playing. Drives the bottom accessory and is the
    /// source of content for the matched-zoom sheet that the accessory
    /// button presents.
    private var nowPlayingItem: NowPlayingItem? {
        if let articleID = audioPlayer.currentArticleID,
           let article = feedManager.article(byID: articleID) {
            return .podcast(article)
        }
        if let article = youTubeSession.currentArticle {
            return .youTube(article)
        }
        return nil
    }

    func body(content: Content) -> some View {
        @Bindable var presenter = mediaPresenter
        return content
            .tabViewBottomAccessory(isEnabled: nowPlayingItem != nil) {
                Button {
                    // MUST be this exactly, or SwiftUI goes bonkers
                    isSheetPresented = true
                } label: {
                    accessoryContent
                        .matchedTransitionSource(id: "NowPlayingBar", in: namespace)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            // Sheet for Now Playing bar - MUST use isSheetPresented
            .sheet(isPresented: $isSheetPresented) {
                NavigationStack {
                    if let item = nowPlayingItem {
                        sheetContent(for: item)
                    }
                }
                .presentationDragIndicator(.visible)
                .navigationTransition(
                    .zoom(sourceID: "NowPlayingBar", in: namespace)
                )
            }
            // Sheet for Now Playing triggered from other views
            .sheet(item: $presenter.presentedItem) { item in
                NavigationStack {
                    sheetContent(for: item)
                }
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var accessoryContent: some View {
        if let item = nowPlayingItem {
            switch item {
            case .podcast: MiniPlayerBar()
            case .youTube: YouTubeMiniPlayerBar()
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for item: NowPlayingItem) -> some View {
        switch item {
        case .podcast(let article):
            PodcastEpisodeView(article: article, showsDismissButton: true)
        case .youTube(let article):
            YouTubePlayerView(article: article, showsDismissButton: true)
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
