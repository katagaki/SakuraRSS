import SwiftUI
import Hanami

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

// MARK: - Ephemeral Article Navigation Environment

private struct EphemeralArticleNavigationActionKey: EnvironmentKey {
    static let defaultValue: ((EphemeralArticleDestination) -> Void)? = nil
}

extension EnvironmentValues {
    /// Pushes an ephemeral article onto the host's navigation path. Provided by
    /// hosts whose `NavigationStack` is wired to handle `EphemeralArticleDestination`,
    /// so in-article link taps land in the same path as other pushes (and
    /// subsequent navigations stack on top correctly).
    var navigateToEphemeralArticle: ((EphemeralArticleDestination) -> Void)? {
        get { self[EphemeralArticleNavigationActionKey.self] }
        set { self[EphemeralArticleNavigationActionKey.self] = newValue }
    }
}

// MARK: - Summary Headline Navigation Environment

private struct SummaryHeadlineNavigationActionKey: EnvironmentKey {
    static let defaultValue: ((SummaryHeadlineDestination) -> Void)? = nil
}

extension EnvironmentValues {
    var navigateToSummaryHeadline: ((SummaryHeadlineDestination) -> Void)? {
        get { self[SummaryHeadlineNavigationActionKey.self] }
        set { self[SummaryHeadlineNavigationActionKey.self] = newValue }
    }
}

// MARK: - Zoom Transition Modifiers

extension View {
    func zoomTransition<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID) -> some View {
        ZoomTransitionModifier(sourceID: sourceID, namespace: namespace, wrappedView: self)
    }

    @ViewBuilder
    func zoomTransition<ID: Hashable>(sourceID: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            ZoomTransitionModifier(sourceID: sourceID, namespace: namespace, wrappedView: self)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomSource<ID: Hashable>(id: ID, namespace: Namespace.ID?) -> some View {
        if let namespace {
            ZoomSourceModifier(id: id, namespace: namespace, wrappedView: self)
        } else {
            self
        }
    }

    @ViewBuilder
    func matchedSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}

private struct ZoomTransitionModifier<ID: Hashable, WrappedView: View>: View {
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true
    let sourceID: ID
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

private struct ZoomSourceModifier<ID: Hashable, WrappedView: View>: View {
    @AppStorage("Display.ZoomTransition") private var zoomTransitionEnabled: Bool = true
    let id: ID
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
