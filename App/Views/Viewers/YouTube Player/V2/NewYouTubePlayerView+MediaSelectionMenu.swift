import AVFoundation
import SwiftUI

extension NewYouTubePlayerView {

    var hasMediaSelectionOptions: Bool {
        !playback.audioOptions.isEmpty || !playback.subtitleOptions.isEmpty
    }

    @ViewBuilder
    var mediaSelectionMenu: some View {
        Menu {
            if !playback.audioOptions.isEmpty {
                Section(String(localized: "YouTube.MediaSelection.Audio", table: "Integrations")) {
                    ForEach(playback.audioOptions, id: \.self) { option in
                        Button {
                            playback.selectAudioOption(option)
                        } label: {
                            audioOptionLabel(for: option)
                        }
                    }
                }
            }
            if !playback.subtitleOptions.isEmpty {
                Section(String(localized: "YouTube.MediaSelection.Subtitles", table: "Integrations")) {
                    Button {
                        playback.selectSubtitleOption(nil)
                    } label: {
                        subtitleOffLabel
                    }
                    ForEach(playback.subtitleOptions, id: \.self) { option in
                        Button {
                            playback.selectSubtitleOption(option)
                        } label: {
                            subtitleOptionLabel(for: option)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
        }
    }

    @ViewBuilder
    private func audioOptionLabel(for option: AVMediaSelectionOption) -> some View {
        if option == playback.currentAudioOption {
            Label(option.displayName, systemImage: "checkmark")
        } else {
            Text(option.displayName)
        }
    }

    @ViewBuilder
    private func subtitleOptionLabel(for option: AVMediaSelectionOption) -> some View {
        if option == playback.currentSubtitleOption {
            Label(option.displayName, systemImage: "checkmark")
        } else {
            Text(option.displayName)
        }
    }

    @ViewBuilder
    private var subtitleOffLabel: some View {
        let title = String(localized: "YouTube.MediaSelection.SubtitlesOff", table: "Integrations")
        if playback.currentSubtitleOption == nil {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
