import SwiftUI

struct HomeSettingsView: View {

    @State private var configuration: HomeBarConfiguration = .load()
    @State private var editMode: EditMode = .active

    var body: some View {
        List {
            Section {
                ForEach(configuration.orderedItems, id: \.self) { kind in
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
        .onChange(of: configuration) { _, newValue in
            newValue.save()
            NotificationCenter.default.post(name: .homeBarConfigurationDidChange, object: nil)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        configuration.orderedItems.move(fromOffsets: source, toOffset: destination)
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
            Label(kind.localizedTitle, systemImage: kind.systemImage)
        }
        .tint(.accent)
    }
}
