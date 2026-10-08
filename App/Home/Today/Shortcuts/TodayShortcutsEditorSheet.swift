import SwiftUI
import Hanami

struct TodayShortcutsEditorSheet: View {

    let items: [TodayShortcutItem]
    let title: (TodayShortcutItem) -> String
    let symbolName: (TodayShortcutItem) -> String

    @Environment(\.dismiss) private var dismiss
    @State private var orderedItems: [TodayShortcutItem] = []
    private let preferences = TodayShortcutPreferences.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(orderedItems) { item in
                        Toggle(isOn: visibilityBinding(for: item)) {
                            Label(title(item), systemImage: symbolName(item))
                        }
                    }
                    .onMove { source, destination in
                        orderedItems.move(fromOffsets: source, toOffset: destination)
                        preferences.saveOrder(orderedItems)
                    }
                } footer: {
                    Text(String(localized: "Today.Shortcuts.Footer", table: "Home"))
                }

                Section {
                    Button(String(localized: "Today.Shortcuts.Reset", table: "Home"), role: .destructive) {
                        preferences.reset()
                        withAnimation(.smooth.speed(2.0)) {
                            orderedItems = preferences.ordered(items)
                        }
                    }
                    .disabled(!preferences.isCustomized)
                }
            }
            .settingsListStyle()
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle(String(localized: "Today.Shortcuts.Edit", table: "Home"))
            .inlineNavigationTitle()
            .compatibleSoftScrollEdgeEffectStyle()
            .toolbar {
                ToolbarItem(placement: .sheetTrailing) {
                    Button(role: .confirm) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                orderedItems = preferences.ordered(items)
            }
        }
    }

    private func visibilityBinding(for item: TodayShortcutItem) -> Binding<Bool> {
        Binding(
            get: { !preferences.isHidden(item) },
            set: { preferences.setHidden(!$0, for: item) }
        )
    }
}
