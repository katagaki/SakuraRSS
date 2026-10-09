import EnhancedNavigation
import SwiftUI

/// Wires the app's navigation closures into a tab's path. The page's chrome
/// is EnhancedNavigation's bar, so the top bar goes.
struct BrowserNavigationEnvironment: ViewModifier {

    @Environment(BrowserTabStore.self) private var store
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .environment(\.navigateToFeed) { path.append($0) }
            .environment(\.navigateToEphemeralArticle) { path.append($0) }
            .environment(\.navigateToSummaryHeadline) { path.append($0) }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .interactivePopGesture(for: store)
    }
}

extension View {
    func browserNavigationEnvironment(path: Binding<NavigationPath>) -> some View {
        modifier(BrowserNavigationEnvironment(path: path))
    }
}
