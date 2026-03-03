import SwiftUI
import FoundationModels

struct OnboardingView: View {

    @Environment(FeedManager.self) var feedManager
    @AppStorage("Display.DefaultStyle") private var defaultDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("Search.DisplayStyle") private var searchDisplayStyle: FeedDisplayStyle = .inbox
    @AppStorage("BackgroundRefresh.Enabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("TodaysSummary.Enabled") private var todaysSummaryEnabled: Bool = true
    @AppStorage("WhileYouSlept.Enabled") private var whileYouSleptEnabled: Bool = true

    @State private var showAddFirstFeed = false
    var onComplete: () -> Void

    private var isAppleIntelligenceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    settingsSection
                    Spacer(minLength: 16)
                    getStartedButton
                }
                .padding()
            }
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .navigationDestination(isPresented: $showAddFirstFeed) {
                AddFirstFeedView(onComplete: onComplete)
                    .environment(feedManager)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 32)
            Text("Onboarding.Welcome.Title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Onboarding.Welcome.Subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(
                icon: "newspaper",
                title: String(localized: "Onboarding.Feature.Feeds"),
                description: String(localized: "Onboarding.Feature.Feeds.Description")
            )
            featureRow(
                icon: "rectangle.grid.2x2",
                title: String(localized: "Onboarding.Feature.ViewStyles"),
                description: String(localized: "Onboarding.Feature.ViewStyles.Description")
            )
            featureRow(
                icon: "headphones",
                title: String(localized: "Onboarding.Feature.Podcasts"),
                description: String(localized: "Onboarding.Feature.Podcasts.Description")
            )
            featureRow(
                icon: "apple.intelligence",
                title: String(localized: "Onboarding.Feature.Summaries"),
                description: String(localized: "Onboarding.Feature.Summaries.Description")
            )
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            // Default Style
            VStack(alignment: .leading, spacing: 8) {
                Picker(String(localized: "Onboarding.Setting.DefaultStyle"), selection: Binding(
                    get: { defaultDisplayStyle },
                    set: { newValue in
                        defaultDisplayStyle = newValue
                        searchDisplayStyle = newValue
                    }
                )) {
                    Text("Articles.Style.Inbox")
                        .tag(FeedDisplayStyle.inbox)
                    Text("Articles.Style.Feed")
                        .tag(FeedDisplayStyle.feed)
                    Text("Articles.Style.Magazine")
                        .tag(FeedDisplayStyle.magazine)
                    Text("Articles.Style.Compact")
                        .tag(FeedDisplayStyle.compact)
                    Text("Articles.Style.Photos")
                        .tag(FeedDisplayStyle.photos)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            Divider()
                .padding(.leading)

            // Background Refresh
            Toggle(String(localized: "Onboarding.Setting.BackgroundRefresh"), isOn: $backgroundRefreshEnabled)
                .padding(.horizontal)
                .padding(.vertical, 12)

            if isAppleIntelligenceAvailable {
                Divider()
                    .padding(.leading)

                // Summaries
                Toggle(String(localized: "Onboarding.Setting.Summaries"), isOn: Binding(
                    get: { todaysSummaryEnabled && whileYouSleptEnabled },
                    set: { newValue in
                        todaysSummaryEnabled = newValue
                        whileYouSleptEnabled = newValue
                    }
                ))
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Get Started

    private var getStartedButton: some View {
        Button {
            showAddFirstFeed = true
        } label: {
            Text("Onboarding.GetStarted")
                .padding()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
    }
}
