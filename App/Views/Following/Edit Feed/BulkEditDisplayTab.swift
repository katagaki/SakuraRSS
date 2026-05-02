import SwiftUI

struct BulkEditDisplayTab: View {

    let feedIDs: Set<Int64>
    var onApplied: () -> Void

    @State private var displayEnabled: Bool = false
    @State private var selectedStyle: FeedDisplayStyle = .inbox

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "FeedList.BulkEdit.Display.Change", table: "Feeds"),
                       isOn: $displayEnabled)
            } header: {
                Text(String(localized: "DisplayStyle", table: "Articles"))
            } footer: {
                Text(String(
                    localized: "FeedList.BulkEdit.Display.Footer.\(feedIDs.count)",
                    table: "Feeds"
                ))
            }

            if displayEnabled {
                DisplayStylePicker(
                    displayStyle: $selectedStyle,
                    hasImages: true,
                    showTimeline: true,
                    showPodcast: true,
                    showCards: true,
                    showScroll: true
                )
            }

            Section {
                Button {
                    applyToAll()
                } label: {
                    Text(String(
                        localized: "FeedList.BulkEdit.Display.Apply.\(feedIDs.count)",
                        table: "Feeds"
                    ))
                }
                .disabled(feedIDs.isEmpty)
            }
        }
    }

    private func applyToAll() {
        for feedID in feedIDs {
            if displayEnabled {
                UserDefaults.standard.set(selectedStyle.rawValue, forKey: "Display.Style.\(feedID)")
            } else {
                UserDefaults.standard.removeObject(forKey: "Display.Style.\(feedID)")
            }
        }
        onApplied()
    }
}
