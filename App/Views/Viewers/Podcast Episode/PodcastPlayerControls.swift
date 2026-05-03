import SwiftUI

struct PodcastPlayerControls: View {

    let audioPlayer: AudioPlayer
    let hasTranscript: Bool
    @Binding var showingTranscript: Bool
    @Binding var playbackSpeed: Double
    let playbackSpeedPresets: [Double]

    var body: some View {
        HStack(spacing: 32) {
            transcriptToggle

            Spacer(minLength: 0)

            Button { audioPlayer.skipBackward() } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 22))
            }

            Button { audioPlayer.togglePlayPause() } label: {
                Image(systemName: audioPlayer.isPlaying
                      ? "pause.circle.fill"
                      : "play.circle.fill")
                    .font(.system(size: 62))
            }

            Button { audioPlayer.skipForward() } label: {
                Image(systemName: "goforward.30")
                    .font(.system(size: 22))
            }

            Spacer(minLength: 0)

            playbackSpeedMenu
        }
        .foregroundStyle(.primary)
        #if os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    private var transcriptToggle: some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                showingTranscript.toggle()
            }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.system(size: 22))
                .foregroundStyle(showingTranscript ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .disabled(!hasTranscript)
    }

    private var playbackSpeedMenu: some View {
        Menu {
            Picker(String(localized: "PlaybackSpeed", table: "Podcast"), selection: $playbackSpeed) {
                ForEach(playbackSpeedPresets, id: \.self) { preset in
                    Text(formatSpeed(preset))
                        .tag(preset)
                }
            }
        } label: {
            Image(systemName: gaugeIcon(for: playbackSpeed))
                .font(.system(size: 22))
                .foregroundStyle(.primary)
        }
        .onChange(of: playbackSpeed) { _, newValue in
            audioPlayer.setPlaybackRate(Float(newValue))
        }
    }

    private func gaugeIcon(for speed: Double) -> String {
        switch speed {
        case ...0.75:
            return "gauge.with.dots.needle.0percent"
        case 0.76...1.0:
            return "gauge.with.dots.needle.33percent"
        case 1.01...1.5:
            return "gauge.with.dots.needle.50percent"
        case 1.51...2.0:
            return "gauge.with.dots.needle.67percent"
        default:
            return "gauge.with.dots.needle.100percent"
        }
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == floor(speed) {
            return "\(Int(speed))×"
        }
        let formatted = String(format: "%g", speed)
        return "\(formatted)×"
    }
}
