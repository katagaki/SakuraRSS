import SwiftUI

struct BrowsingSettingsView: View {

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .day1
    @AppStorage("Articles.AutoLoadWhileScrolling") private var autoLoadWhileScrolling: Bool = false
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false

    var body: some View {
        List {
            Section {
                Picker(selection: $batchingMode) {
                    Section {
                        Text(String(localized: "Batching.Day1", table: "Settings"))
                            .tag(BatchingMode.day1)
                        Text(String(localized: "Batching.Day3", table: "Settings"))
                            .tag(BatchingMode.day3)
                        Text(String(localized: "Batching.Week1", table: "Settings"))
                            .tag(BatchingMode.week1)
                    }
                    Section {
                        Text(String(localized: "Batching.Items25", table: "Settings"))
                            .tag(BatchingMode.items25)
                        Text(String(localized: "Batching.Items50", table: "Settings"))
                            .tag(BatchingMode.items50)
                        Text(String(localized: "Batching.Items100", table: "Settings"))
                            .tag(BatchingMode.items100)
                    }
                    Section {
                        Text(String(localized: "Batching.Off", table: "Settings"))
                            .tag(BatchingMode.off)
                    }
                } label: {
                    Text(String(localized: "BatchingMode", table: "Settings"))
                }
            } header: {
                Text(String(localized: "Section.ContentGrouping", table: "Settings"))
            } footer: {
                Text(String(localized: "Batching.Footer", table: "Settings"))
            }

            Section {
                Toggle(String(localized: "AutoLoadWhileScrolling", table: "Settings"),
                       isOn: $autoLoadWhileScrolling)
                Toggle(String(localized: "ScrollMarkAsRead", table: "Settings"), isOn: $scrollMarkAsRead)
            } header: {
                Text(String(localized: "Section.Scrolling", table: "Settings"))
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Browsing", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
