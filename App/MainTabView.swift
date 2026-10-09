import SwiftUI
import TipKit
import Hanami

struct MainTabView: View {

    @Environment(FeedManager.self) var feedManager
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
        .compatibleSoftScrollEdgeEffectStyle()
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
}
