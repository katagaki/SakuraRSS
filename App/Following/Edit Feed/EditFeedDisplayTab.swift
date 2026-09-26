import SwiftUI
import Hanami

/// Per-feed display style. Lives here rather than in the article list's toolbar
/// so it survives the browser layout, which has no top bar.
struct EditFeedDisplayTab: View {

    let feedID: Int64

    @State private var usesCustomStyle: Bool = false
    @State private var selectedStyle: FeedDisplayStyle = .inbox

    private var storageKey: String { "Display.Style.\(feedID)" }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "FeedEditSheet.Display.UseCustom", table: "Feeds"),
                       isOn: $usesCustomStyle)
            } header: {
                Text(String(localized: "DisplayStyle", table: "Articles"))
            } footer: {
                Text(String(localized: "FeedEditSheet.Display.Footer", table: "Feeds"))
            }

            if usesCustomStyle {
                DisplayStylePicker(
                    displayStyle: $selectedStyle,
                    hasImages: true,
                    showTimeline: true,
                    showPodcast: true,
                    showCards: true,
                    showScroll: true
                )
            }
        }
        .task {
            let stored = UserDefaults.standard.string(forKey: storageKey)
            usesCustomStyle = stored != nil
            selectedStyle = stored.flatMap(FeedDisplayStyle.init(rawValue:)) ?? .inbox
        }
        .onChange(of: usesCustomStyle) { _, isOn in
            persist(isEnabled: isOn, style: selectedStyle)
        }
        .onChange(of: selectedStyle) { _, style in
            persist(isEnabled: usesCustomStyle, style: style)
        }
    }

    private func persist(isEnabled: Bool, style: FeedDisplayStyle) {
        if isEnabled {
            UserDefaults.standard.set(style.rawValue, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
}
