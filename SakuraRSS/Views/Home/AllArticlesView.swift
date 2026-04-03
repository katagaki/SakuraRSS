import SwiftUI

enum HomeSection: String, CaseIterable, Identifiable {
    case feed
    case news
    case social
    case videos
    case audio

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .feed: String(localized: "Shared.AllArticles")
        case .news: String(localized: "HomeSection.News")
        case .social: String(localized: "HomeSection.Social")
        case .videos: String(localized: "HomeSection.Videos")
        case .audio: String(localized: "HomeSection.Audio")
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "square.stack"
        case .news: "newspaper"
        case .social: "person.2"
        case .videos: "play.rectangle"
        case .audio: "headphones"
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .feed: nil
        case .news: .news
        case .social: .social
        case .videos: .video
        case .audio: .audio
        }
    }
}

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") private var selectedSection: HomeSection = .feed
    @State private var showingOlderArticles = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @State private var whileYouSleptAvailable = false
    @State private var todaysSummaryAvailable = false

    private var todayDateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var anySummaryHidden: Bool {
        (whileYouSleptDismissedDate == todayDateKey && whileYouSleptAvailable)
        || (todaysSummaryDismissedDate == todayDateKey && todaysSummaryAvailable)
    }

    private var displayedArticles: [Article] {
        if showingOlderArticles {
            return feedManager.todayArticles() + feedManager.olderArticles()
        } else {
            return feedManager.todayArticles()
        }
    }

    var body: some View {
        Group {
            switch selectedSection {
            case .feed:
                feedTabContent
            case .news:
                HomeSectionView(section: .news)
            case .social:
                HomeSectionView(section: .social)
            case .videos:
                HomeSectionView(section: .video)
            case .audio:
                HomeSectionView(section: .audio)
            }
        }
        .navigationTitle(selectedSection.localizedTitle)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarTitleMenu {
            ForEach(availableSections) { section in
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        selectedSection = section
                    }
                } label: {
                    Label(section.localizedTitle, systemImage: section.systemImage)
                }
            }
        }
        .onChange(of: availableSections) {
            if !availableSections.contains(selectedSection) {
                selectedSection = .feed
            }
        }
    }

    private var availableSections: [HomeSection] {
        HomeSection.allCases.filter { section in
            guard let feedSection = section.feedSection else { return true }
            return feedManager.hasFeeds(for: feedSection)
        }
    }

    private var feedTabContent: some View {
        ArticlesView(
            articles: displayedArticles,
            title: HomeSection.feed.localizedTitle,
            feedKey: "all",
            anySummaryHidden: anySummaryHidden,
            onRestoreSummaries: {
                withAnimation(.smooth.speed(2.0)) {
                    whileYouSleptDismissedDate = ""
                    todaysSummaryDismissedDate = ""
                }
            },
            onLoadMore: showingOlderArticles ? nil : {
                showingOlderArticles = true
            },
            onRefresh: {
                await feedManager.refreshAllFeeds()
            },
            onMarkAllRead: {
                feedManager.markAllRead()
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                WhileYouSleptView(
                    hasSummary: $whileYouSleptAvailable
                )
                TodaysSummaryView(
                    hasSummary: $todaysSummaryAvailable
                )
            }
            .animation(.smooth.speed(2.0), value: whileYouSleptDismissedDate)
            .animation(.smooth.speed(2.0), value: todaysSummaryDismissedDate)
            .padding(.bottom, 8)
        }
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            if markAllReadPosition == .bottom {
                ArticlesToolbar {
                    feedManager.markAllRead()
                }
            }
        }
    }
}
