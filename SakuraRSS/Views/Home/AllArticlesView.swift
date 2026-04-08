import SwiftUI

enum HomeSection: String, CaseIterable, Identifiable {
    case feed
    case social
    case videos
    case audio

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .feed: String(localized: "Shared.AllArticles")
        case .social: String(localized: "HomeSection.Social")
        case .videos: String(localized: "HomeSection.Videos")
        case .audio: String(localized: "HomeSection.Audio")
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "square.stack"
        case .social: "person.2"
        case .videos: "play.rectangle"
        case .audio: "headphones"
        }
    }

    var feedSection: FeedSection? {
        switch self {
        case .feed: nil
        case .social: .social
        case .videos: .video
        case .audio: .audio
        }
    }
}

/// Represents the selected view in the Home tab title menu.
/// Can be a static section or a user-created list.
enum HomeSelection: Hashable, RawRepresentable {
    case section(HomeSection)
    case list(Int64)

    var rawValue: String {
        switch self {
        case .section(let s): "section.\(s.rawValue)"
        case .list(let id): "list.\(id)"
        }
    }

    init?(rawValue: String) {
        if rawValue.hasPrefix("section.") {
            let sectionRaw = String(rawValue.dropFirst("section.".count))
            if let section = HomeSection(rawValue: sectionRaw) {
                self = .section(section)
                return
            }
        } else if rawValue.hasPrefix("list.") {
            let idStr = String(rawValue.dropFirst("list.".count))
            if let id = Int64(idStr) {
                self = .list(id)
                return
            }
        }
        // Legacy migration: bare section names from before the HomeSelection wrapper
        if let section = HomeSection(rawValue: rawValue) {
            self = .section(section)
            return
        }
        return nil
    }

    var localizedTitle: String {
        switch self {
        case .section(let s): s.localizedTitle
        case .list: ""
        }
    }

    var systemImage: String {
        switch self {
        case .section(let s): s.systemImage
        case .list: ""
        }
    }
}

struct AllArticlesView: View {

    @Environment(FeedManager.self) var feedManager

    @AppStorage("Home.SelectedSection") private var selectedSelection: HomeSelection = .section(.feed)
    @State private var showingOlderArticles = false
    @AppStorage("Display.MarkAllReadPosition") private var markAllReadPosition: MarkAllReadPosition = .bottom
    @AppStorage("WhileYouSlept.DismissedDate") private var whileYouSleptDismissedDate: String = ""
    @AppStorage("TodaysSummary.DismissedDate") private var todaysSummaryDismissedDate: String = ""
    @AppStorage("Instagram.HideReels") private var hideInstagramReels: Bool = false
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
        var articles: [Article]
        if showingOlderArticles {
            articles = feedManager.todayArticles() + feedManager.olderArticles()
        } else {
            articles = feedManager.todayArticles()
        }
        if hideInstagramReels {
            articles = articles.filter { !$0.url.contains("/reel/") }
        }
        return articles
    }

    private var currentTitle: String {
        switch selectedSelection {
        case .section(let s):
            return s.localizedTitle
        case .list(let id):
            return feedManager.lists.first { $0.id == id }?.name
                ?? String(localized: "Shared.AllArticles")
        }
    }

    var body: some View {
        Group {
            switch selectedSelection {
            case .section(let section):
                switch section {
                case .feed:
                    feedTabContent
                case .social:
                    HomeSectionView(section: .social)
                case .videos:
                    HomeSectionView(section: .video)
                case .audio:
                    HomeSectionView(section: .audio)
                }
            case .list(let id):
                if let list = feedManager.lists.first(where: { $0.id == id }) {
                    ListSectionView(list: list)
                } else {
                    feedTabContent
                }
            }
        }
        .navigationTitle(currentTitle)
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbarTitleMenu {
            ForEach(availableSections) { section in
                Button {
                    withAnimation(.smooth.speed(2.0)) {
                        selectedSelection = .section(section)
                    }
                } label: {
                    Label(section.localizedTitle, systemImage: section.systemImage)
                }
            }

            if !feedManager.lists.isEmpty {
                Divider()
                ForEach(feedManager.lists) { list in
                    Button {
                        withAnimation(.smooth.speed(2.0)) {
                            selectedSelection = .list(list.id)
                        }
                    } label: {
                        Label(list.name, systemImage: list.icon)
                    }
                }
            }
        }
        .onChange(of: availableSections) {
            validateSelection()
        }
        .onChange(of: feedManager.lists) {
            validateSelection()
        }
    }

    private func validateSelection() {
        switch selectedSelection {
        case .section(let section):
            if !availableSections.contains(section) {
                selectedSelection = .section(.feed)
            }
        case .list(let id):
            if !feedManager.lists.contains(where: { $0.id == id }) {
                selectedSelection = .section(.feed)
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
