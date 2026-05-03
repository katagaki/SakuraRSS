import SwiftUI

extension IPadSidebarView {

    @ViewBuilder
    var contentColumn: some View {
        Group {
            if !searchText.isEmpty {
                iPadArticleListWrapper {
                    IPadSearchResultsView(searchResults: searchResults)
                }
            } else {
                switch selectedDestination {
                case .today:
                    iPadTodayContent()
                case .allArticles:
                    iPadAllArticlesContent()
                case .section(let section):
                    iPadSectionContent(section: section)
                case .bookmarks:
                    iPadBookmarksContent()
                case .topics:
                    iPadArticleListWrapper {
                        TopicsView()
                    }
                case .people:
                    iPadArticleListWrapper {
                        PeopleView()
                    }
                case .list(let list):
                    iPadListContent(list: list)
                case .feed(let feed):
                    iPadFeedContent(feed: feed)
                case .more, .none:
                    ContentUnavailableView {
                        Label(String(localized: "Sidebar.SelectSection", table: "Feeds"),
                              systemImage: "sidebar.left")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var detailContent: some View {
        if let firstEphemeral = ephemeralDestinations.first {
            NavigationStack(path: ephemeralPathBinding) {
                ArticleDestinationView(
                    article: firstEphemeral.article,
                    overrideMode: firstEphemeral.mode,
                    overrideTextMode: firstEphemeral.textMode
                )
                .id(firstEphemeral.article.url)
                .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                .navigationDestination(for: EphemeralArticleDestination.self) { destination in
                    ArticleDestinationView(
                        article: destination.article,
                        overrideMode: destination.mode,
                        overrideTextMode: destination.textMode
                    )
                    .id(destination.article.url)
                    .environment(\.navigateToEphemeralArticle, ephemeralAppender)
                }
            }
        } else {
            NavigationStack {
                if let article = selectedArticle {
                    ArticleDestinationView(article: article)
                        .id(article.id)
                } else {
                    ContentUnavailableView {
                        Label(String(localized: "Sidebar.SelectArticle", table: "Feeds"),
                              systemImage: "doc.text")
                    } description: {
                        Text(String(localized: "Sidebar.SelectArticle.Description", table: "Feeds"))
                    }
                }
            }
        }
    }

    private var ephemeralAppender: (EphemeralArticleDestination) -> Void {
        { destination in ephemeralDestinations.append(destination) }
    }

    private var ephemeralPathBinding: Binding<[EphemeralArticleDestination]> {
        let bound = $ephemeralDestinations
        return Binding(
            get: { Array(bound.wrappedValue.dropFirst()) },
            set: { newPath in
                if let first = bound.wrappedValue.first {
                    bound.wrappedValue = [first] + newPath
                } else {
                    bound.wrappedValue = newPath
                }
            }
        )
    }

    @ViewBuilder
    func iPadTodayContent() -> some View {
        iPadArticleListWrapper {
            TodayView()
                .navigationTitle(String(localized: "HomeSection.Today", table: "Home"))
                .toolbarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    func iPadAllArticlesContent() -> some View {
        iPadArticleListWrapper {
            AllArticlesView()
        }
    }

    @ViewBuilder
    func iPadSectionContent(section: FeedSection) -> some View {
        iPadArticleListWrapper {
            HomeSectionView(section: section)
                .navigationTitle(section.localizedTitle)
                .toolbarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    func iPadBookmarksContent() -> some View {
        iPadArticleListWrapper {
            BookmarksContentView()
        }
    }

    @ViewBuilder
    func iPadFeedContent(feed: Feed) -> some View {
        iPadArticleListWrapper {
            FeedArticlesView(feed: feed)
        }
        .id(feed.id)
    }

    @ViewBuilder
    func iPadListContent(list: FeedList) -> some View {
        iPadArticleListWrapper {
            HomeSectionView(list: list)
                .navigationTitle(list.name)
                .toolbarTitleDisplayMode(.inline)
        }
        .id(list.id)
    }

    @ViewBuilder
    func iPadArticleListWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .environment(\.navigateToFeed, { feed in
                    selectedDestination = .feed(feed)
                })
                .environment(\.zoomNamespace, cardZoom)
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationDestination(for: Feed.self) { feed in
                    FeedArticlesView(feed: feed)
                        .environment(\.iPadArticleSelection, $selectedArticle)
                        .environment(\.zoomNamespace, cardZoom)
                }
                .navigationDestination(for: EntityDestination.self) { destination in
                    EntityArticlesView(destination: destination)
                        .environment(\.iPadArticleSelection, $selectedArticle)
                        .environment(\.zoomNamespace, cardZoom)
                }
                .environment(\.iPadArticleSelection, $selectedArticle)
        }
    }
}
