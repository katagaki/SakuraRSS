import EnhancedNavigation
import SwiftUI
import Hanami

/// The new-tab landing. Today carries the page, with Quick Access and
/// recent content pinned directly below the greeting.
struct BrowserStartPage: View {

    @Environment(FeedManager.self) private var feedManager
    @Environment(\.isBrowserChromeActive) private var isBrowserChromeActive
    @State private var isPresentingNewListSheet = false
    @State private var isEditingQuickAccess = false
    @State private var isPresentingWeatherSettings = false

    var body: some View {
        #if os(visionOS)
        // visionOS has no Today, so the start page keeps its own sections there.
        BrowserFallbackStartPage()
        #else
        TodayView(
            pinnedSection: AnyView(
                VStack(alignment: .leading, spacing: 16) {
                    BrowserTodayQuickAccessGrid(
                        isEditing: isEditingQuickAccess,
                        onBeginEditing: { setEditingQuickAccess(true) }
                    )
                    if !isEditingQuickAccess {
                        BrowserRecentContentSection()
                    }
                }
                .padding(.horizontal)
            ),
            isEditing: isEditingQuickAccess
        )
        .safeAreaInset(edge: .bottom) {
            if isEditingQuickAccess {
                TodayQuickAccessEndEditingButton { setEditingQuickAccess(false) }
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .tabOmniboxAccessory(isEnabled: isBrowserChromeActive) {
            BrowserStartPageMenu(actions: BrowserStartPageActions(
                newList: { isPresentingNewListSheet = true },
                editQuickAccess: { setEditingQuickAccess(true) },
                showWeatherSettings: { isPresentingWeatherSettings = true }
            ))
        }
        .sheet(isPresented: $isPresentingNewListSheet) {
            ListEditSheet(list: nil)
                .environment(feedManager)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isPresentingWeatherSettings) {
            TodayWeatherSettingsSheet()
                .presentationDetents([.medium, .large])
        }
        #endif
    }

    private func setEditingQuickAccess(_ isEditing: Bool) {
        withAnimation(.smooth.speed(2.0)) {
            isEditingQuickAccess = isEditing
        }
    }
}
