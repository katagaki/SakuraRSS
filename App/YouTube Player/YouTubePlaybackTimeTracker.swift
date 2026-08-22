import Foundation

/// Reference type so tracking the last observed playback time does not
/// invalidate the player's body on every coalesced time event.
final class YouTubePlaybackTimeTracker {
    var lastCheckedTime: TimeInterval = 0
}
