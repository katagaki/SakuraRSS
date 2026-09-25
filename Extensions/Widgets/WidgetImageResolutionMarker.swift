import Foundation

/// Records the article set whose images were fully resolved. The marker is only
/// stored once every image resolved, so a jetsam kill or an offline wake retries
/// instead of permanently skipping downloads; a bounded attempt count still stops
/// endless retries of genuinely broken images.
struct WidgetImageResolutionMarker {

    let defaults: UserDefaults?
    let markerKey: String

    private static let maxAttempts = 3

    private var attemptCountKey: String { "\(markerKey)_attempts" }
    private var attemptMarkerKey: String { "\(markerKey)_attemptsFor" }

    static func marker(for articleIDs: [Int64]) -> String {
        articleIDs.map(String.init).joined(separator: ",")
    }

    func isUnchanged(_ marker: String) -> Bool {
        defaults?.string(forKey: markerKey) == marker
    }

    func record(_ marker: String, allImagesResolved: Bool) {
        guard let defaults else { return }
        guard !allImagesResolved else {
            defaults.set(marker, forKey: markerKey)
            defaults.removeObject(forKey: attemptCountKey)
            defaults.removeObject(forKey: attemptMarkerKey)
            return
        }
        let previousAttempts = defaults.string(forKey: attemptMarkerKey) == marker
            ? defaults.integer(forKey: attemptCountKey)
            : 0
        let attempts = previousAttempts + 1
        if attempts >= Self.maxAttempts {
            defaults.set(marker, forKey: markerKey)
            defaults.removeObject(forKey: attemptCountKey)
            defaults.removeObject(forKey: attemptMarkerKey)
        } else {
            defaults.set(attempts, forKey: attemptCountKey)
            defaults.set(marker, forKey: attemptMarkerKey)
        }
    }
}
