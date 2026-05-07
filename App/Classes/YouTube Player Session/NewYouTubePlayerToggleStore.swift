import SwiftUI

/// Non-persistent in-memory store backing the experimental "New YouTube
/// Player" toggle. The setting intentionally resets to `false` every launch
/// so the experimental player is only enabled for the current session.
@MainActor
@Observable
final class NewYouTubePlayerToggleStore {

    static let shared = NewYouTubePlayerToggleStore()

    var isEnabled = false

    private init() {}
}
