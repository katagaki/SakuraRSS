import Foundation
import UIKit

/// Unified result type returned by all integrations after scraping.
/// Each integration transforms its platform-specific parsed items into
/// `ArticleInsertItem`s inside `scrape(identifier:)`, so the FeedManager
/// refresh path doesn't need to know about platform-specific result types.
struct IntegrationScrapeResult {
    let articles: [ArticleInsertItem]
    /// Optional updated feed title (e.g. profile display name, playlist title).
    /// When nil, the existing feed title is kept.
    let feedTitle: String?
    /// Optional URL of a profile photo to download and use as the feed's
    /// custom favicon. Only used when `supportsProfilePhoto` is true.
    let profileImageURL: String?

    init(
        articles: [ArticleInsertItem] = [],
        feedTitle: String? = nil,
        profileImageURL: String? = nil
    ) {
        self.articles = articles
        self.feedTitle = feedTitle
        self.profileImageURL = profileImageURL
    }
}

/// Base class for social media / platform integrations.
///
/// Subclasses implement platform-specific scraping (API calls, HTML parsing,
/// session management) while the base class provides the shared surface used
/// by `FeedManager+Integration.swift` to route refreshes uniformly.
///
/// ## Overriding
///
/// Subclasses **must** override:
/// - `feedURLScheme` — pseudo-feed URL prefix, e.g. `"x-profile://"`
/// - `scrape(identifier:)` — perform the fetch and return a unified result
///
/// Subclasses **may** override:
/// - `refreshInterval` (default: 30 minutes)
/// - `requiresAuthentication` (default: false)
/// - `supportsProfilePhoto` (default: false)
/// - `hasSession()` / `clearSession()` (defaults: always-true / no-op)
class Integration {

    /// Explicit nonisolated initializer so subclasses can be instantiated
    /// from any actor context (e.g. `IntegrationRegistry` called from the
    /// `FaviconCache` actor). Without this, the default-main-actor
    /// isolation setting would make `init()` @MainActor-isolated and
    /// break synchronous lookups.
    nonisolated init() {}

    /// Per-request timeout used by integration network calls that build
    /// their own `URLRequest`s (e.g. the X GraphQL API, Instagram's web
    /// profile endpoint).  Callers performing cosmetic work — favicon
    /// avatar lookups in particular — can raise this value to bypass the
    /// default 15s timeout since an avatar fetch is non-critical and
    /// should not fail on slow networks.
    ///
    /// Marked `nonisolated(unsafe)` so the `FaviconCache` actor can tweak
    /// it before calling a scrape method.  The value is only ever set
    /// before network calls start, so there is no meaningful data race.
    nonisolated(unsafe) var requestTimeoutInterval: TimeInterval = 15

    // MARK: - Required overrides

    /// Pseudo-feed URL scheme prefix, e.g. `"x-profile://"`.
    /// Subclasses MUST override this. Marked `nonisolated` so that the
    /// URL-matching helpers below (which are called from actor-isolated
    /// code like `FaviconCache`) stay fully synchronous.
    nonisolated class var feedURLScheme: String {
        fatalError("Subclass must override `feedURLScheme`")
    }

    /// Performs the platform-specific fetch and returns a unified result.
    /// Subclasses MUST override this.
    ///
    /// - Parameter identifier: The identifier extracted from the pseudo-feed
    ///   URL via `identifierFromFeedURL(_:)` — e.g. an X handle, Instagram
    ///   handle, or YouTube playlist ID.
    func scrape(identifier: String) async -> IntegrationScrapeResult {
        fatalError("Subclass must override `scrape(identifier:)`")
    }

    // MARK: - Feed URL helpers (provided)

    /// Checks whether a feed URL belongs to this integration.
    nonisolated class func isFeedURL(_ url: String) -> Bool {
        url.hasPrefix(feedURLScheme)
    }

    /// Extracts the platform-specific identifier from a pseudo-feed URL.
    nonisolated class func identifierFromFeedURL(_ url: String) -> String? {
        guard isFeedURL(url) else { return nil }
        return String(url.dropFirst(feedURLScheme.count))
    }

    /// Constructs a pseudo-feed URL for the given identifier.
    nonisolated class func feedURL(for identifier: String) -> String {
        "\(feedURLScheme)\(identifier.lowercased())"
    }

    // MARK: - Overridable defaults

    /// Minimum interval between refreshes of a single feed. Default: 30 minutes.
    nonisolated class var refreshInterval: TimeInterval { 30 * 60 }

    /// Whether this integration requires authentication to fetch content.
    /// Default: `false`. Subclasses like X and Instagram override to `true`.
    nonisolated class var requiresAuthentication: Bool { false }

    /// Whether this integration can supply a profile photo to use as the
    /// feed's custom favicon. Default: `false`.
    nonisolated class var supportsProfilePhoto: Bool { false }

    /// Whether the user currently has an active session for this integration.
    /// Default: `true` (for integrations that don't require authentication).
    @MainActor
    class func hasSession() async -> Bool { true }

    /// Clears any persisted session state for this integration.
    /// Default: no-op.
    @MainActor
    class func clearSession() async { }

    // MARK: - Profile Photo

    /// Returns the URL of the profile photo for a given identifier, or nil
    /// if the integration cannot supply one. Subclasses that set
    /// `supportsProfilePhoto = true` should override this.
    ///
    /// This is split out from `fetchProfilePhoto` so subclasses only have
    /// to implement the lightweight URL-resolution step; the base class
    /// handles downloading the image bytes.
    func profileImageURL(forIdentifier identifier: String) async -> String? {
        nil
    }

    /// Downloads and returns the profile photo for a feed belonging to
    /// this integration, or nil if one is unavailable.
    ///
    /// The default implementation calls `profileImageURL(forIdentifier:)`
    /// and downloads the result. Subclasses typically only need to
    /// override the URL-resolution step.
    ///
    /// Because profile-photo fetches are cosmetic, they bump
    /// `requestTimeoutInterval` to a long value so the profile-info API
    /// call won't time out on a slow network, and use the dedicated
    /// `FaviconCache.urlSession` (which has equally long timeouts) to
    /// download the image bytes.
    func fetchProfilePhoto(forFeedURL url: String) async -> UIImage? {
        guard Self.supportsProfilePhoto,
              let identifier = Self.identifierFromFeedURL(url) else {
            return nil
        }
        requestTimeoutInterval = 600
        guard let imageURLString = await profileImageURL(forIdentifier: identifier),
              let imageURL = URL(string: imageURLString),
              let (data, _) = try? await FaviconCache.urlSession.data(from: imageURL) else {
            return nil
        }
        return UIImage(data: data)
    }
}

// MARK: - Integration Registry

/// Maps a feed's pseudo-URL to the correct `Integration` subclass so that
/// call sites (FaviconCache, FeedEditSheet, etc.) don't need to hard-code
/// per-platform branching. Adding a new integration should only require
/// adding a single entry here.
enum IntegrationRegistry {

    /// Returns a fresh integration instance for the given feed URL, or
    /// nil if the URL does not belong to any registered integration.
    ///
    /// Marked `nonisolated` so that actor-isolated callers (e.g.
    /// `FaviconCache`) can look up an integration without an actor hop.
    nonisolated static func integration(forFeedURL url: String) -> Integration? {
        if XIntegration.isFeedURL(url) { return XIntegration() }
        if InstagramIntegration.isFeedURL(url) { return InstagramIntegration() }
        if YouTubePlaylistIntegration.isFeedURL(url) { return YouTubePlaylistIntegration() }
        return nil
    }

    /// All registered integration types. Useful for diagnostics/settings
    /// views that want to enumerate every available integration.
    nonisolated static var allTypes: [Integration.Type] {
        [
            XIntegration.self,
            InstagramIntegration.self,
            YouTubePlaylistIntegration.self
        ]
    }
}
