import SwiftUI
import Hanami

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

// MARK: - Matched Transition Source

extension View {
    @ViewBuilder
    func matchedSource<ID: Hashable>(id: ID, in namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }
}
