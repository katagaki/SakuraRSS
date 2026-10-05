import SwiftUI
import TipKit
import Hanami

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    @AppStorage("Onboarding.Completed") private var onboardingCompleted: Bool = false
    @AppStorage(WhatsNewRelease.lastShownVersionKey) private var whatsNewLastShownVersion: String = ""
    @Binding var pendingFeedURL: String?
    @Binding var pendingArticleID: Int64?
    @Binding var pendingOpenRequest: OpenArticleRequest?
    @State private var showingOnboarding = false
    @State private var showingWhatsNew = false
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
            .sheet(isPresented: $showingWhatsNew) {
                whatsNewLastShownVersion = WhatsNewRelease.version
            } content: {
                WhatsNewView {
                    showingWhatsNew = false
                }
            }
            .onAppear {
                if !onboardingCompleted {
                    showingOnboarding = true
                } else if WhatsNewRelease.isUnseen(lastShownVersion: whatsNewLastShownVersion) {
                    showingWhatsNew = true
                }
            }
    }

    private var onboardingSheet: some View {
        OnboardingView {
            onboardingCompleted = true
            whatsNewLastShownVersion = WhatsNewRelease.version
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
