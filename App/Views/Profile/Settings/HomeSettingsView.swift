import SwiftUI

struct HomeSettingsView: View {

    @Environment(FeedManager.self) var feedManager
    @State private var configuration: HomeBarConfiguration = .load()
    @State private var editMode: EditMode = .active
    @State private var showResetConfirmation: Bool = false

    var body: some View {
        List {
            Section {
                ForEach(visibleItems, id: \.self) { kind in
                    HomeBarItemRow(
                        kind: kind,
                        isEnabled: enabledBinding(for: kind)
                    )
                }
                .onMove(perform: move)
            } header: {
                Text(String(localized: "Home.SectionBar.Title", table: "Settings"))
            } footer: {
                Text(String(localized: "Home.SectionBar.Footer", table: "Settings"))
            }

            if configuration.enabledItems.contains(.topics) {
                Section {
                    Picker(
                        String(localized: "Home.Topics.Count", table: "Settings"),
                        selection: topicCountBinding
                    ) {
                        ForEach(HomeBarTopicCount.allCases) { option in
                            Text(option.localizedTitle).tag(option)
                        }
                    }
                } header: {
                    Text(String(localized: "Home.BarItem.Topics", table: "Settings"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .sakuraBackground()
        .environment(\.editMode, $editMode)
        .navigationTitle(String(localized: "Section.Home", table: "Settings"))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Home.Reset", table: "Settings")) {
                    showResetConfirmation = true
                }
            }
        }
        .alert(
            String(localized: "Home.Reset.ConfirmTitle", table: "Settings"),
            isPresented: $showResetConfirmation
        ) {
            Button(String(localized: "Home.Reset", table: "Settings"), role: .destructive) {
                configuration = .default
            }
            Button("Shared.Cancel", role: .cancel) {}
        } message: {
            Text(String(localized: "Home.Reset.ConfirmMessage", table: "Settings"))
        }
        .onChange(of: configuration) { _, newValue in
            newValue.save()
            NotificationCenter.default.post(name: .homeBarConfigurationDidChange, object: nil)
        }
    }

    /// Filters out per-section items the user has no feeds for, while
    /// preserving order so hidden items keep their saved positions.
    private var visibleItems: [HomeBarItemKind] {
        configuration.orderedItems.filter(isVisible)
    }

    private func isVisible(_ kind: HomeBarItemKind) -> Bool {
        guard let feedSection = kind.feedSection else { return true }
        return feedManager.hasFeeds(for: feedSection)
    }

    private func move(from source: IndexSet, to destination: Int) {
        var newVisible = visibleItems
        newVisible.move(fromOffsets: source, toOffset: destination)

        var visibleIndices: [Int] = []
        for (index, kind) in configuration.orderedItems.enumerated() where isVisible(kind) {
            visibleIndices.append(index)
        }

        var newOrdered = configuration.orderedItems
        for (visibleIndex, absoluteIndex) in visibleIndices.enumerated() {
            newOrdered[absoluteIndex] = newVisible[visibleIndex]
        }
        configuration.orderedItems = newOrdered
    }

    private func enabledBinding(for kind: HomeBarItemKind) -> Binding<Bool> {
        Binding(
            get: { configuration.enabledItems.contains(kind) },
            set: { isOn in
                if isOn {
                    configuration.enabledItems.insert(kind)
                } else {
                    configuration.enabledItems.remove(kind)
                }
            }
        )
    }

    private var topicCountBinding: Binding<HomeBarTopicCount> {
        Binding(
            get: { configuration.topicCount },
            set: { configuration.topicCount = $0 }
        )
    }
}

private struct HomeBarItemRow: View {

    let kind: HomeBarItemKind
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            Text(kind.localizedTitle)
        }
    }
}
