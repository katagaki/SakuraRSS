import SwiftUI

struct BrowsingSettingsView: View {

    @AppStorage("Articles.BatchingMode") private var batchingMode: BatchingMode = .items25
    @AppStorage("Articles.HideViewedContent") private var hideViewedContent: Bool = false
    @AppStorage("Display.ScrollMarkAsRead") private var scrollMarkAsRead: Bool = false
    @AppStorage(DoomscrollingMode.storageKey) private var doomscrollingMode: Bool = false

    private var hideViewedContentBinding: Binding<Bool> {
        Binding(
            get: { doomscrollingMode ? false : hideViewedContent },
            set: { newValue in
                guard !doomscrollingMode else { return }
                hideViewedContent = newValue
            }
        )
    }

    private var scrollMarkAsReadBinding: Binding<Bool> {
        Binding(
            get: { doomscrollingMode ? false : scrollMarkAsRead },
            set: { newValue in
                guard !doomscrollingMode else { return }
                scrollMarkAsRead = newValue
            }
        )
    }

    private var batchingModeBinding: Binding<BatchingMode> {
        Binding(
            get: { doomscrollingMode ? .items25 : batchingMode },
            set: { newValue in
                guard !doomscrollingMode else { return }
                batchingMode = newValue
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "HideViewedContent", table: "Settings"),
                       isOn: hideViewedContentBinding)
                    .disabled(doomscrollingMode)
                Picker(selection: batchingModeBinding) {
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
                .disabled(doomscrollingMode)
            } header: {
                Text(String(localized: "Section.Feeds", table: "Settings"))
            } footer: {
                Text(String(localized: "Batching.Footer", table: "Settings"))
            }

            Section {
                Toggle(String(localized: "ScrollMarkAsRead", table: "Settings"),
                       isOn: scrollMarkAsReadBinding)
                    .disabled(doomscrollingMode)
            } header: {
                Text(String(localized: "Section.Scrolling", table: "Settings"))
            }

            Section {
                Toggle(String(localized: "Doomscrolling.Enable", table: "Settings"),
                       isOn: Binding(
                            get: { doomscrollingMode },
                            set: { newValue in
                                withAnimation(.smooth.speed(2.0)) {
                                    doomscrollingMode = newValue
                                }
                            }
                       ))
                    .tint(.red)
            } header: {
                Text(String(localized: "Section.Doomscrolling", table: "Settings"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .sakuraBackground()
        .navigationTitle(String(localized: "Section.Browsing", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
    }
}
