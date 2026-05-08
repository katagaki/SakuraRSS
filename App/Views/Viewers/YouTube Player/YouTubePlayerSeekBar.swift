import SwiftUI

/// Reads `currentTime` and `duration` from the player session inside its own
/// body so periodic time updates don't invalidate the surrounding player view.
struct YouTubePlayerSeekBar: View {

    let session: YouTubePlayerSession
    let isAd: Bool
    let segments: [(start: Double, end: Double)]
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        SeekBarView(
            currentTime: session.currentTime,
            duration: session.duration,
            isDisabled: isAd,
            segments: segments,
            onSeek: onSeek
        )
    }
}
