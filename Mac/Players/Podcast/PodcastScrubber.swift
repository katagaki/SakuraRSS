import SwiftUI

/// The shared player's position on iOS's flat seek bar, read twice a second.
struct PodcastScrubber: View {

    let player: AudioPlayer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            SeekBarView(currentTime: player.currentTime(), duration: player.duration) { time in
                player.seek(to: time)
            }
        }
    }
}
