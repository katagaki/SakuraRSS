import SwiftUI

struct PodcastPlaybackControls: View {

    static let speedPresets: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    let player: AudioPlayer
    let isCurrentEpisode: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button { player.skipBackward() } label: {
                Image(systemName: "gobackward.15").font(.system(size: 20))
            }
            .disabled(!isCurrentEpisode)
            Button {
                if isCurrentEpisode {
                    player.togglePlayPause()
                } else {
                    onPlay()
                }
            } label: {
                Image(systemName: isCurrentEpisode && player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52))
                    .symbolRenderingMode(.hierarchical)
            }
            Button { player.skipForward() } label: {
                Image(systemName: "goforward.30").font(.system(size: 20))
            }
            .disabled(!isCurrentEpisode)
            speedMenu
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var speedMenu: some View {
        Menu {
            Picker(
                String(localized: "PlaybackSpeed", table: "Podcast"),
                selection: Binding(
                    get: { Double(player.playbackRate) },
                    set: { player.setPlaybackRate(Float($0)) }
                )
            ) {
                ForEach(Self.speedPresets, id: \.self) { preset in
                    Text(Self.label(for: preset)).tag(preset)
                }
            }
        } label: {
            Text(Self.label(for: Double(player.playbackRate)))
                .font(.callout.monospacedDigit())
        }
        .menuStyle(.button)
        .fixedSize()
    }

    private static func label(for speed: Double) -> String {
        speed == floor(speed) ? "\(Int(speed))×" : "\(String(format: "%g", speed))×"
    }
}
