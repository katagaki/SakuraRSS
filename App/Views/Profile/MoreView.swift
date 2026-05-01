import SwiftUI

struct MoreView: View {

    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(FeedManager.self) private var feedManager
    @Namespace private var cardZoom

    @State private var isShowingNewList = false
    @State private var listToEdit: FeedList?
    @State private var listForRules: FeedList?
    @State private var listToDelete: FeedList?

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Section.Analytics", table: "Settings")) {
                    AnalyticsView()
                }

                MoreListsSection(
                    listToEdit: $listToEdit,
                    listForRules: $listForRules,
                    listToDelete: $listToDelete,
                    isShowingNewList: $isShowingNewList
                )

                Section {
                    NavigationLink {
                        HomeSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Home", table: "Settings"),
                            systemImage: "house.fill",
                            color: .red
                        )
                    }
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Appearance", table: "Settings"),
                            systemImage: "paintpalette.fill",
                            color: .orange
                        )
                    }
                    NavigationLink {
                        BrowsingSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Browsing", table: "Settings"),
                            systemImage: "book.fill",
                            color: .blue
                        )
                    }
                    NavigationLink {
                        FetchingSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Refreshing", table: "Settings"),
                            systemImage: "arrow.triangle.2.circlepath",
                            color: .green
                        )
                    }
                    NavigationLink {
                        IntegrationsSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Integrations", table: "Settings"),
                            systemImage: "puzzlepiece.extension.fill",
                            color: .indigo
                        )
                    }
                    NavigationLink {
                        OnDeviceIntelligenceSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.InsightsAndIntelligence", table: "Settings"),
                            systemImage: "sparkles",
                            color: .pink
                        )
                    }
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Data", table: "Settings"),
                            systemImage: "externaldrive.fill",
                            color: .gray
                        )
                    }
                } header: {
                    Text(String(localized: "Section.Settings", table: "Settings"))
                }

                Section {
                    Link(destination: URL(string: "https://github.com/katagaki/SakuraRSS")!) {
                        HStack {
                            Text("More.SourceCode")
                            Spacer()
                            Text("katagaki/SakuraRSS")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                    NavigationLink {
                        AttributesView()
                    } label: {
                        Text("More.Attribution")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sakuraBackground()
            .navigationTitle("Tabs.Profile")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
            .navigationDestination(for: FeedList.self) { list in
                HomeSectionView(list: list)
                    .environment(\.zoomNamespace, cardZoom)
                    .environment(\.navigateToFeed, { _ in })
            }
            .navigationDestination(for: Feed.self) { feed in
                FeedArticlesView(feed: feed)
                    .environment(\.zoomNamespace, cardZoom)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDestinationView(article: article)
                    .environment(\.zoomNamespace, cardZoom)
                    .zoomTransition(sourceID: article.id, in: cardZoom)
            }
            .navigationDestination(for: EntityDestination.self) { destination in
                EntityArticlesView(destination: destination)
                    .environment(\.zoomNamespace, cardZoom)
            }
            .sheet(isPresented: $isShowingNewList) {
                ListEditSheet(list: nil)
                    .environment(feedManager)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled()
            }
            .sheet(item: $listToEdit) { list in
                ListEditSheet(list: list)
                    .environment(feedManager)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled()
            }
            .sheet(item: $listForRules) { list in
                ListRulesSheet(list: list)
                    .environment(feedManager)
                    .presentationDetents([.medium, .large])
                    .interactiveDismissDisabled()
            }
            .alert(
                String(localized: "ListMenu.Delete.Title", table: "Lists"),
                isPresented: Binding(
                    get: { listToDelete != nil },
                    set: { if !$0 { listToDelete = nil } }
                )
            ) {
                Button(String(localized: "ListMenu.Delete.Confirm", table: "Lists"), role: .destructive) {
                    if let list = listToDelete {
                        feedManager.deleteList(list)
                        listToDelete = nil
                    }
                }
                Button("Shared.Cancel", role: .cancel) {
                    listToDelete = nil
                }
            } message: {
                if let list = listToDelete {
                    Text(String(localized: "ListMenu.Delete.Message.\(list.name)", table: "Lists"))
                }
            }
        }
    }
}
