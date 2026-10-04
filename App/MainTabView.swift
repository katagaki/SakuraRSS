import SwiftUI
import TipKit
import Hanami

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State private var showingOnboarding = false
    private let audioPlayer = AudioPlayer.shared
    private let youTubeSession = YouTubePlayerSession.shared
    private let mediaPresenter = MediaPresenter.shared

    var body: some View {
        Group {
            #if os(iOS)
            browserView
            #else
            standardView
            #endif
        }
        .compatibleSoftScrollEdgeEffectStyle()
        #if os(visionOS)
        .onAppear {
            mediaPresenter.detachedHandler = { item in
                switch item {
                case .youTube(let article):
                    openWindow(id: "YouTubePlayerWindow", value: article.id)
                case .podcast(let article):
                    openWindow(id: "PodcastPlayerWindow", value: article.id)
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var browserView: some View {
        BrowserView(
            pendingFeedURL: $pendingFeedURL,
            pendingArticleID: $pendingArticleID,
            pendingOpenRequest: $pendingOpenRequest
        )
            .miniPlayerAccessory(
                audioPlayer: audioPlayer,
                youTubeSession: youTubeSession,
                mediaPresenter: mediaPresenter
            )
            .sheet(isPresented: $showingOnboarding) {
                onboardingSheet
            }
            .onAppear {
                if !onboardingCompleted {
                    showingOnboarding = true
                }
            }
    }

    private var onboardingSheet: some View {
        OnboardingView {
            onboardingCompleted = true
            ViewStyleSwitcherTip.hasCompletedOnboarding = true
            showingOnboarding = false
        }
        .environment(feedManager)
    }

    private var standardView: some View {
        iPadSidebarView(
            pendingFeedURL: $pendingFeedURL,
            pendingArticleID: $pendingArticleID,
            pendingOpenRequest: $pendingOpenRequest
        )
    }
}
