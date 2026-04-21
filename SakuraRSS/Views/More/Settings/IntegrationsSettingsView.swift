import SwiftUI

struct IntegrationsSettingsView: View {

    var body: some View {
        List {
            Section {
                NavigationLink(String(localized: "Podcast", table: "Integrations")) {
                    PodcastSettingsView()
                }
            } header: {
                Text(String(localized: "Section.Podcasts", table: "Settings"))
            }

            Section {
                NavigationLink(String(localized: "Petal", table: "Integrations")) {
                    PetalSettingsView()
                }
            } header: {
                Text(String(localized: "Section.WebFeeds", table: "Settings"))
            }

            Section {
                NavigationLink(String(localized: "ArchivePh", table: "Integrations")) {
                    ArchivePhSettingsView()
                }
                NavigationLink(String(localized: "ClearThisPage", table: "Integrations")) {
                    ClearThisPageSettingsView()
                }
                NavigationLink(String(localized: "Instagram", table: "Integrations")) {
                    InstagramSettingsView()
                }
                NavigationLink(String(localized: "X", table: "Integrations")) {
                    XSettingsView()
                }
                NavigationLink(String(localized: "YouTube", table: "Integrations")) {
                    YouTubeSettingsView()
                }
            } header: {
                Text(String(localized: "Section.OtherServices", table: "Settings"))
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Integrations", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
