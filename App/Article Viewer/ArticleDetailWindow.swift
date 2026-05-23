#if targetEnvironment(macCatalyst)
import SwiftUI
import Hanami

struct ArticleDetailWindow: View {

    @Environment(FeedManager.self) private var feedManager
    let articleID: Int64
    @State private var navigationPath: [EphemeralArticleDestination] = []
    @State private var youTubeSession = YouTubePlayerSession()
    @State private var audioPlayer = AudioPlayer()

    private var article: Article? {
        feedManager.article(byID: articleID)
    }

    var body: some View {
        ZStack {
            FreeResizabilityHelper()
                .frame(width: 0, height: 0)
            if let article {
                NavigationStack(path: $navigationPath) {
                    ArticleDestinationView(article: article)
                        .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                            ArticleDestinationView(
                                article: destination.article,
                                overrideMode: destination.mode,
                                overrideTextMode: destination.textMode
                            )
                            .environment(\.navigateToEphemeralArticle) { next in
                                navigationPath.append(next)
                            }
                        }
                        .environment(\.navigateToEphemeralArticle) { destination in
                            navigationPath.append(destination)
                        }
                }
                .environment(\.youTubePlayerSession, youTubeSession)
                .environment(\.podcastAudioPlayer, audioPlayer)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onDisappear {
            youTubeSession.clear()
            audioPlayer.stop()
        }
    }
}

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
