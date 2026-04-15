import SwiftUI

extension PodcastEpisodeView {

    var transcriptToggle: some View {
        Button {
            withAnimation(.smooth.speed(2.0)) {
                showingTranscript.toggle()
            }
        } label: {
            Image(systemName: "quote.bubble")
                .font(.title3)
                .foregroundStyle(showingTranscript ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
        }
        .buttonStyle(.plain)
        .disabled(transcript == nil)
    }

    var playbackSpeedMenu: some View {
        Menu {
            Picker(String(localized: "PlaybackSpeed", table: "Podcast"), selection: $playbackSpeed) {
                ForEach(playbackSpeedPresets, id: \.self) { preset in
                    Text(formatSpeed(preset))
                        .tag(preset)
                }
            }
        } label: {
            Image(systemName: gaugeIcon(for: playbackSpeed))
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .onChange(of: playbackSpeed) { _, newValue in
            audioPlayer.setPlaybackRate(Float(newValue))
        }
    }

    func gaugeIcon(for speed: Double) -> String {
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
}
