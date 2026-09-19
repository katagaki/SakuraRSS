import SwiftUI

/// A zoom transition whose source is a top bar button the browser doesn't
/// show. Without a source the transition has nothing to grow from, so it
/// falls back to the standard presentation there.
struct OptionalZoomTransition<ID: Hashable>: ViewModifier {

    let isEnabled: Bool
    let sourceID: ID
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
    func optionalZoomTransition<ID: Hashable>(
        isEnabled: Bool,
        sourceID: ID,
        in namespace: Namespace.ID
    ) -> some View {
        modifier(OptionalZoomTransition(isEnabled: isEnabled, sourceID: sourceID, namespace: namespace))
    }
}
