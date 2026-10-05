import SwiftUI

/// The video's position on iOS's flat seek bar, with the times beside it.
struct YouTubeScrubber: View {

    let session: YouTubePlayerSession
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        SeekBarView(
            currentTime: session.currentTime,
            duration: session.duration,
            labelLayout: .inline,
            onSeek: onSeek
        )
    }
}
