import SwiftUI

struct MoreView: View {

    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(FeedManager.self) private var feedManager
    @Namespace private var cardZoom

    var body: some View {
        NavigationStack {
            List {
                Section(String(localized: "Section.Analytics", table: "Settings")) {
                    AnalyticsView()
                }

                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Appearance", table: "Settings"),
                            systemImage: "paintpalette.fill",
                            color: .orange
                        )
                    }
                    if UIDevice.current.userInterfaceIdiom != .pad {
                        NavigationLink {
                            HomeSettingsView()
                        } label: {
                            SettingsIconLabel(
                                String(localized: "Section.Home", table: "Settings"),
                                systemImage: "newspaper.fill",
                                color: .red
                            )
                        }
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
                    Link(destination: URL(string: "https://testflight.apple.com/join/Vhb17waj")!) {
                        HStack {
                            Text("More.TestFlight")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
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
            .toolbarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .inline : .inlineLarge)
            #if targetEnvironment(macCatalyst)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
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
        }
    }
}
