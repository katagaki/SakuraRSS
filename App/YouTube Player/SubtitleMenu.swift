import SwiftUI
import Hanami

struct SubtitleMenu: View, Equatable {

    let tracks: [YouTubeCaptionTrack]
    let onSelect: (String) -> Void

    static func == (lhs: SubtitleMenu, rhs: SubtitleMenu) -> Bool {
        lhs.tracks == rhs.tracks
    }

    private var isOffSelected: Bool {
        !tracks.contains { $0.isSelected }
    }

    var body: some View {
        Menu {
            Button {
                onSelect("")
            } label: {
                if isOffSelected {
                    Label(
                        String(localized: "YouTube.MediaSelection.SubtitlesOff", table: "Integrations"),
                        systemImage: "checkmark"
                    )
                } else {
                    Text(String(localized: "YouTube.MediaSelection.SubtitlesOff", table: "Integrations"))
                }
            }

            Divider()

            ForEach(tracks) { track in
                Button {
                    onSelect(track.code)
                } label: {
                    if track.isSelected {
                        Label(track.name, systemImage: "checkmark")
                    } else {
                        Text(track.name)
                    }
                }
            }
        } label: {
            Label(
                String(localized: "YouTube.MediaSelection.Subtitles", table: "Integrations"),
                systemImage: "captions.bubble"
            )
        }
    }
}
