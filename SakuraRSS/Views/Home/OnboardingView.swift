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
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    featuresSection
                    settingsSection
                    stylePreviewSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .safeAreaInset(edge: .bottom) {
                getStartedButton
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(.bar)
            }
            .navigationDestination(isPresented: $showAddFirstFeed) {
                AddFirstFeedView(onComplete: onComplete)
                    .environment(feedManager)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text("Onboarding.Welcome.Title")
                .font(.largeTitle.bold())
            Text("Onboarding.Welcome.Subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32, alignment: .center)
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

            Divider()
                .padding(.leading)

            // Default Style
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
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Style Preview

    private var stylePreviewSection: some View {
        StylePreviewView(style: defaultDisplayStyle)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false)
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

// MARK: - Style Preview

private struct StylePreviewView: View {

    let style: FeedDisplayStyle

    private var sampleArticles: [Article] {
        [
            Article(id: 1, feedID: 1,
                    title: String(localized: "Onboarding.Sample.Title1"),
                    url: "", author: String(localized: "Onboarding.Sample.Author1"),
                    summary: String(localized: "Onboarding.Sample.Summary1"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-3600),
                    isRead: false, isBookmarked: false),
            Article(id: 2, feedID: 1,
                    title: String(localized: "Onboarding.Sample.Title2"),
                    url: "", author: String(localized: "Onboarding.Sample.Author2"),
                    summary: String(localized: "Onboarding.Sample.Summary2"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-7200),
                    isRead: true, isBookmarked: false),
            Article(id: 3, feedID: 1,
                    title: String(localized: "Onboarding.Sample.Title3"),
                    url: "", author: String(localized: "Onboarding.Sample.Author3"),
                    summary: String(localized: "Onboarding.Sample.Summary3"),
                    imageURL: nil, publishedDate: Date().addingTimeInterval(-10800),
                    isRead: false, isBookmarked: true),
        ]
    }

    var body: some View {
        Group {
            switch style {
            case .inbox, .video, .podcast:
                inboxPreview
            case .feed:
                feedPreview
            case .magazine, .photos:
                magazinePreview
            case .compact:
                compactPreview
            }
        }
        .background(.regularMaterial)
    }

    // MARK: - Inbox Preview

    private var inboxPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(article.isRead ? .clear : .blue)
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(article.title)
                            .font(.body)
                            .fontWeight(article.isRead ? .regular : .semibold)
                            .lineLimit(1)
                            .foregroundStyle(article.isRead ? .secondary : .primary)
                        if let summary = article.summary {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let author = article.author, let date = article.publishedDate {
                            HStack(spacing: 8) {
                                Text(author)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                RelativeTimeText(date: date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if article.id != sampleArticles.last?.id {
                    Divider()
                        .padding(.leading, 32)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Feed Preview

    private var feedPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            if let author = article.author {
                                Text(author)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                            }
                            if let date = article.publishedDate {
                                Text("·")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                RelativeTimeText(date: date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !article.isRead {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        if let summary = article.summary {
                            Text(summary)
                                .font(.subheadline)
                                .lineLimit(3)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if article.id != sampleArticles.last?.id {
                    Divider()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Magazine Preview

    private var magazinePreview: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(sampleArticles) { article in
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 100)
                    Text(article.title)
                        .font(.subheadline)
                        .fontWeight(article.isRead ? .regular : .semibold)
                        .lineLimit(2)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                    if let date = article.publishedDate {
                        RelativeTimeText(date: date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: - Compact Preview

    private var compactPreview: some View {
        VStack(spacing: 0) {
            ForEach(sampleArticles) { article in
                HStack {
                    Text(article.title)
                        .font(.caption)
                        .fontWeight(article.isRead ? .regular : .medium)
                        .foregroundStyle(article.isRead ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if let date = article.publishedDate {
                        RelativeTimeText(date: date)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if article.id != sampleArticles.last?.id {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
