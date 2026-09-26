import EnhancedNavigation
import SwiftUI

/// Wires the app's navigation closures into a tab's path. In compact layout
/// the page's chrome is the tab's `BrowserBottomBar`, so the top bar goes.
struct BrowserNavigationEnvironment: ViewModifier {

    @Environment(\.browserLayout) private var layout
    @Environment(BrowserTabStore.self) private var store
    @Binding var path: NavigationPath
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .environment(\.zoomNamespace, namespace)
            .environment(\.navigateToFeed) { path.append($0) }
            .environment(\.navigateToEphemeralArticle) { path.append($0) }
            .environment(\.navigateToSummaryHeadline) { path.append($0) }
            .toolbarVisibility(layout == .compact ? .hidden : .automatic, for: .navigationBar)
            .interactivePopGesture(for: store)
    }
}

extension View {
    func browserNavigationEnvironment(
        path: Binding<NavigationPath>,
        namespace: Namespace.ID
    ) -> some View {
        modifier(BrowserNavigationEnvironment(path: path, namespace: namespace))
    }
}
