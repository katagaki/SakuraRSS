import SwiftUI
import Hanami

struct TodayQuickAccessEditorSheet: View {

    let items: [TodayQuickAccessItem]
    let title: (TodayQuickAccessItem) -> String
    let symbolName: (TodayQuickAccessItem) -> String

    @SheetDismiss private var dismiss
    @State private var orderedItems: [TodayQuickAccessItem] = []
    private let preferences = TodayQuickAccessPreferences.shared

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
                    Text(String(localized: "Today.QuickAccess.Footer", table: "Home"))
                }

                Section {
                    Button(String(localized: "Today.QuickAccess.Reset", table: "Home"), role: .destructive) {
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
            .sheetTitle(String(localized: "Today.QuickAccess.Edit", table: "Home"))
            .compatibleSoftScrollEdgeEffectStyle()
            .sheetActions {
                EmptyView()
            } trailing: {
                Button(role: .confirm) {
                    dismiss()
                }
            }
            .onEscape {
                dismiss()
            }
            .onAppear {
                orderedItems = preferences.ordered(items)
            }
        }
    }

    private func visibilityBinding(for item: TodayQuickAccessItem) -> Binding<Bool> {
        Binding(
            get: { !preferences.isHidden(item) },
            set: { preferences.setHidden(!$0, for: item) }
        )
    }
}
