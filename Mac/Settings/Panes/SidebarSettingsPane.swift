import Hanami
import SwiftUI

struct SidebarSettingsPane: View {

    let feedManager: FeedManager

    private let preferences = TodayQuickAccessPreferences.shared

    private var orderedItems: [TodayQuickAccessItem] {
        preferences.ordered(TodayQuickAccessItem.macItems(in: feedManager))
    }

    var body: some View {
        SettingsForm {
            LabeledContent(String(localized: "Today.QuickAccess.Title", table: "Home")) {
                VStack(alignment: .leading, spacing: 8) {
                    List {
                        ForEach(orderedItems) { item in
                            Toggle(isOn: visibilityBinding(for: item)) {
                                Label(
                                    item.location?.title(in: feedManager) ?? "",
                                    systemImage: item.location?.symbolName(in: feedManager) ?? "square.grid.2x2"
                                )
                            }
                        }
                        .onMove(perform: move)
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                    .frame(width: 360, height: 260)
                    SettingsNote(text: String(localized: "Today.QuickAccess.Footer", table: "Home"))
                    Button(String(localized: "Today.QuickAccess.Reset", table: "Home")) {
                        preferences.reset()
                    }
                    .disabled(!preferences.isCustomized)
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var items = orderedItems
        items.move(fromOffsets: source, toOffset: destination)
        preferences.saveOrder(items)
    }

    private func visibilityBinding(for item: TodayQuickAccessItem) -> Binding<Bool> {
        Binding(
            get: { !preferences.isHidden(item) },
            set: { preferences.setHidden(!$0, for: item) }
        )
    }
}
