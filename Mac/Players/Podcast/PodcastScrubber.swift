import SwiftUI

struct PodcastScrubber: View {

    let player: AudioPlayer
    @State private var draggedTime: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let current = draggedTime ?? player.currentTime()
            let duration = max(player.duration, 1)
            VStack(spacing: 4) {
                Slider(
                    value: Binding(get: { current }, set: { draggedTime = $0 }),
                    in: 0...duration
                ) { isEditing in
                    if !isEditing, let draggedTime {
                        player.seek(to: draggedTime)
                        self.draggedTime = nil
                    }
                }
                .controlSize(.small)
                HStack {
                    Text(Duration.seconds(current), format: .time(pattern: .minuteSecond))
                    Spacer()
                    Text(Duration.seconds(-max(duration - current, 0)), format: .time(pattern: .minuteSecond))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }
}
