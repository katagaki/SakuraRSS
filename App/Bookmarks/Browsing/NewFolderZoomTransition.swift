import SwiftUI

/// The zoom source is the top bar's New Folder button, which the browser
/// doesn't show. Without a source the transition has nothing to grow from,
/// so it falls back to the standard presentation there.
struct NewFolderZoomTransition: ViewModifier {

    let isEnabled: Bool
    let sourceID: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if isEnabled {
            content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            content
        }
    }
}

extension View {
    func newFolderZoomTransition(
        isEnabled: Bool,
        sourceID: String,
        in namespace: Namespace.ID
    ) -> some View {
        modifier(NewFolderZoomTransition(isEnabled: isEnabled, sourceID: sourceID, namespace: namespace))
    }
}
