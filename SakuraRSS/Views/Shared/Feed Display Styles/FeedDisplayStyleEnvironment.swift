import SwiftUI

// MARK: - Zoom Namespace Environment

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

// MARK: - Feed Navigation Environment

private struct FeedNavigationActionKey: EnvironmentKey {
    static let defaultValue: ((Feed) -> Void)? = nil
}

extension EnvironmentValues {
    var navigateToFeed: ((Feed) -> Void)? {
        get { self[FeedNavigationActionKey.self] }
        set { self[FeedNavigationActionKey.self] = newValue }
    }
}

// MARK: - Zoom Transition Modifiers

extension View {
    /// Applies the zoom navigation transition on the destination side.
    /// When no matching `matchedTransitionSource` exists, the system
    /// falls back to the default push transition automatically.
    func zoomTransition(sourceID: Int64, in namespace: Namespace.ID) -> some View {
        self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
    }

    /// Applies the zoom navigation transition on the destination side,
    /// accepting an optional namespace.
    @ViewBuilder
    func zoomTransition(sourceID: Int64, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }

    /// Marks this view as the source for a zoom navigation transition.
    @ViewBuilder
    func zoomSource(id: Int64, namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
