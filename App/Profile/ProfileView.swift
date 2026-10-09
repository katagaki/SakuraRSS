import SwiftUI
import Hanami

struct ProfileView: View {

    /// Sheets want the standard inline title; the tab keeps the large one.
    var titleDisplayMode: ToolbarTitleDisplayMode?

    @Environment(\.dismiss) private var dismiss
    @Environment(FeedManager.self) private var feedManager

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
                        FocusSettingsView()
                    } label: {
                        SettingsIconLabel(
                            String(localized: "Section.Focus", table: "Settings"),
                            systemImage: "moon.fill",
                            color: .purple
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
//                    Link(destination: URL(string: "https://testflight.apple.com/join/Vhb17waj")!) {
//                        HStack {
//                            Text("More.TestFlight")
//                            Spacer()
//                            Image(systemName: "arrow.up.right.square")
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                    .tint(.primary)
                    NavigationLink {
                        AttributesView()
                    } label: {
                        Text("More.Attribution")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tabs.Profile")
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbarTitleDisplayMode(
                titleDisplayMode
                    ?? (UIDevice.current.userInterfaceIdiom == .pad ? .inline : .inlineLarge)
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .environment(\.isSakuraBackgroundDisabled, true)
    }
}
