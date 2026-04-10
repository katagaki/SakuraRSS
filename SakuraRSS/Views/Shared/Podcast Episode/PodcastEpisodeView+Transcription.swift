import SwiftUI

extension PodcastEpisodeView {

    /// Reloads the cached transcript from the database.
    func reloadCachedTranscript() {
        if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
           !cached.isEmpty {
            transcript = cached
        } else {
            transcript = nil
        }
    }
}
