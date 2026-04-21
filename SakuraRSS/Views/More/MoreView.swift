import SwiftUI

struct MoreView: View {

    var showsCloseButton: Bool = true

    @Environment(\.dismiss) private var dismiss

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
                        Text(String(localized: "Section.Appearance", table: "Settings"))
                    }
                    NavigationLink {
                        BrowsingSettingsView()
                    } label: {
                        Text(String(localized: "Section.Browsing", table: "Settings"))
                    }
                    NavigationLink {
                        FetchingSettingsView()
                    } label: {
                        Text(String(localized: "Section.Refreshing", table: "Settings"))
                    }
                    NavigationLink {
                        IntegrationsSettingsView()
                    } label: {
                        Text(String(localized: "Section.Integrations", table: "Settings"))
                    }
                    NavigationLink {
                        OnDeviceIntelligenceSettingsView()
                    } label: {
                        Text(String(localized: "Section.InsightsAndIntelligence", table: "Settings"))
                    }
                    NavigationLink {
                        DataSettingsView()
                    } label: {
                        Text(String(localized: "Section.Data", table: "Settings"))
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
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .sakuraBackground()
            .navigationTitle("Tabs.Profile")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
