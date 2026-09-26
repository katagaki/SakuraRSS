import EnhancedNavigation
import SwiftUI
import Hanami

struct BrowserTabSwitcher: View {

    @Environment(BrowserTabStore.self) private var store
    @Environment(FeedManager.self) private var feedManager
    @State private var isShowingProfile = false

    var body: some View {
        TabSwitcher(
            store: store,
            strings: .browser,
            placeholderIcon: .asset("SakuraIcon"),
            rebuildingPath: { [feedManager] token, path in
                token.append(to: &path, in: feedManager)
            },
            cardLabel: { tab in
                BrowserLocationLabel(
                    description: BrowserLocationDescription.describe(tab, feedManager: feedManager),
                    iconSize: 16,
                    titleFont: .caption.weight(.medium),
                    showsSubtitle: false
                )
            },
            bottomLeadingItem: { profileButton }
        )
        .sheet(isPresented: $isShowingProfile) {
            ProfileView(titleDisplayMode: .inline)
                .environment(feedManager)
        }
    }

    private var profileButton: some View {
        Button {
            isShowingProfile = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel(String(localized: "Tabs.Profile"))
    }
}

private extension TabSwitcherStrings {
    static var browser: TabSwitcherStrings {
        TabSwitcherStrings(
            title: { count in String(localized: "Tabs.Count \(count)", table: "Browser") },
            closeAll: String(localized: "Tabs.CloseAll", table: "Browser"),
            newTab: String(localized: "Menu.NewTab", table: "Browser"),
            closeTab: String(localized: "Menu.CloseTab", table: "Browser")
        )
    }
}
