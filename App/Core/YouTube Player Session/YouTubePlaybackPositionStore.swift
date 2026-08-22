import Foundation

nonisolated enum YouTubePlaybackPositionStore {

    private static let storageKey = "YouTube.PlaybackPositions"
    private static let minimumResumePosition: TimeInterval = 15
    private static let endOfVideoTolerance: TimeInterval = 30
    private static let maximumStoredPositions = 100

    private struct StoredPosition: Codable {
        let position: TimeInterval
        let updatedAt: Date
    }

    static func position(forVideoID videoID: String) -> TimeInterval? {
        guard let stored = storedPositions()[videoID],
              stored.position >= minimumResumePosition else {
            return nil
        }
        return stored.position
    }

    static func save(position: TimeInterval, duration: TimeInterval, forVideoID videoID: String) {
        var positions = storedPositions()
        let isNearEnd = duration > 0 && position >= duration - endOfVideoTolerance
        if position < minimumResumePosition || isNearEnd {
            positions.removeValue(forKey: videoID)
        } else {
            positions[videoID] = StoredPosition(position: position, updatedAt: Date())
        }
        if positions.count > maximumStoredPositions {
            let sorted = positions.sorted { $0.value.updatedAt > $1.value.updatedAt }
            positions = Dictionary(
                uniqueKeysWithValues: sorted.prefix(maximumStoredPositions).map { ($0.key, $0.value) }
            )
        }
        guard let data = try? JSONEncoder().encode(positions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func storedPositions() -> [String: StoredPosition] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: StoredPosition].self, from: data) else {
            return [:]
        }
        return decoded
    }
}
