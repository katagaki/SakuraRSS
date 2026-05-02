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

// MARK: - Feed Item Matched Geometry Namespace

private struct FeedItemNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var feedItemNamespace: Namespace.ID? {
        get { self[FeedItemNamespaceKey.self] }
        set { self[FeedItemNamespaceKey.self] = newValue }
    }
}

extension View {
    func feedMatchedGeometry(_ id: String) -> some View {
        FeedMatchedGeometryModifier(id: id, wrappedView: self)
    }
}

private struct FeedMatchedGeometryModifier<WrappedView: View>: View {
    @Environment(\.feedItemNamespace) private var namespace
    let id: String
    let wrappedView: WrappedView

    var body: some View {
        if let namespace {
            wrappedView.matchedGeometryEffect(id: id, in: namespace)
        } else {
            wrappedView
        }
    }
}

// MARK: - Zoom Transition Modifiers

extension View {
    func zoomTransition(sourceID: Int64, in namespace: Namespace.ID) -> some View {
        ZoomTransitionModifier(sourceID: sourceID, namespace: namespace, wrappedView: self)
    }

    @ViewBuilder
    func zoomTransition(sourceID: Int64, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            ZoomTransitionModifier(sourceID: sourceID, namespace: namespace, wrappedView: self)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomSource(id: Int64, namespace: Namespace.ID?) -> some View {
        if let namespace {
            ZoomSourceModifier(id: id, namespace: namespace, wrappedView: self)
        } else {
            self
        }
    }
}

private struct ZoomTransitionModifier<WrappedView: View>: View {
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true
    let sourceID: Int64
    let namespace: Namespace.ID
    let wrappedView: WrappedView

    var body: some View {
        if zoomTransitionEnabled {
            wrappedView.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            wrappedView
        }
    }
}

private struct ZoomSourceModifier<WrappedView: View>: View {
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true
    let id: Int64
    let namespace: Namespace.ID
    let wrappedView: WrappedView

    var body: some View {
        if zoomTransitionEnabled {
            wrappedView.matchedTransitionSource(id: id, in: namespace)
        } else {
            wrappedView
        }
    }
}
