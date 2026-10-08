import EnhancedNavigation
import SwiftUI
import Hanami

/// The new-tab landing. Today carries the page, with Quick Access and
/// recent content pinned directly below the greeting.
struct BrowserStartPage: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.isBrowserChromeActive) private var isBrowserChromeActive
    @State private var isPresentingNewListSheet = false
    @State private var isPresentingQuickAccessEditor = false
    @State private var isPresentingWeatherSettings = false

    var body: some View {
        #if os(visionOS)
        // visionOS has no Today, so the start page keeps its own sections there.
        BrowserFallbackStartPage()
        #else
        TodayView(pinnedSection: AnyView(
            VStack(alignment: .leading, spacing: 16) {
                BrowserTodayQuickAccessGrid(onEditQuickAccess: { isPresentingQuickAccessEditor = true })
                BrowserRecentContentSection()
            }
            .padding(.horizontal)
        ))
        .tabOmniboxAccessory(isEnabled: isBrowserChromeActive) {
            BrowserStartPageMenu(actions: BrowserStartPageActions(
                newList: { isPresentingNewListSheet = true },
                editQuickAccess: { isPresentingQuickAccessEditor = true },
                showWeatherSettings: { isPresentingWeatherSettings = true }
            ))
        }
        .sheet(isPresented: $isPresentingNewListSheet) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isPresentingQuickAccessEditor) {
            TodayQuickAccessEditorSheet(
                items: TodayQuickAccessItem.browserItems(in: feedManager),
                title: { $0.browserTitle(in: feedManager) },
                symbolName: { $0.browserSymbolName(in: feedManager) }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPresentingWeatherSettings) {
            TodayWeatherSettingsSheet()
                .presentationDetents([.medium, .large])
        }
        #endif
    }
}
