import SwiftUI
import Hanami

/// The Following page's controls, in the bottom bar slot the article viewer
/// uses for its own ellipsis menu.
struct BrowserFollowingMenu: View {

    let actions: BrowserFollowingActions

    var body: some View {
        Menu {
            if actions.isEditing {
                editingItems
            } else {
                browsingItems
            }
        } label: {
            Image(systemName: actions.isEditing ? "pencil.circle.fill" : "ellipsis")
                .font(.system(size: 17))
                .padding(.vertical, 8)
                .contentShape(.rect)
        }
    }

    @ViewBuilder
    private var browsingItems: some View {
        Button(action: actions.addFeed) {
            Label(String(localized: "FeedList.Empty.AddFeed", table: "Feeds"),
                  systemImage: "plus")
        }
        if let beginEditing = actions.beginEditing {
            Section {
                Button(action: beginEditing) {
                    Label(String(localized: "FeedList.Edit", table: "Feeds"),
                          systemImage: "pencil")
                }
            }
        }
    }

    /// Selection acts on what the page has highlighted, so the destructive
    /// and bulk-edit entries only appear once something is picked.
    @ViewBuilder
    private var editingItems: some View {
        if actions.isSelecting {
            if actions.selectedCount > 0 {
                Button(action: actions.editSelected) {
                    Label(String(localized: "FeedList.Selection.Edit", table: "Feeds"),
                          systemImage: "pencil")
                }
                Button(role: .destructive, action: actions.deleteSelected) {
                    Label(String(localized: "FeedList.Selection.Delete", table: "Feeds"),
                          systemImage: "trash")
                }
                Divider()
            }
            Button(role: .cancel, action: actions.toggleSelectMode) {
                Label("Shared.Cancel", systemImage: "xmark")
            }
        } else {
            Button(action: actions.toggleSelectMode) {
                Label(String(localized: "FeedList.Select", table: "Feeds"),
                      systemImage: "checkmark.circle")
            }
            Section {
                Button(action: actions.endEditing) {
                    Label("Shared.Done", systemImage: "checkmark")
                }
            }
        }
    }
}
