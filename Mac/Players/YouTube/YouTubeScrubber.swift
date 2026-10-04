import SwiftUI

struct YouTubeScrubber: View {

    let session: YouTubePlayerSession
    let onSeek: (TimeInterval) -> Void
    @State private var draggedTime: TimeInterval?

    var body: some View {
        let duration = max(session.duration, 1)
        let current = min(draggedTime ?? session.currentTime, duration)
        HStack(spacing: 8) {
            Text(Duration.seconds(current), format: .time(pattern: .minuteSecond))
            Slider(value: Binding(get: { current }, set: { draggedTime = $0 }), in: 0...duration) { isEditing in
                if !isEditing, let draggedTime {
                    onSeek(draggedTime)
                    self.draggedTime = nil
                }
            }
            .controlSize(.small)
            Text(Duration.seconds(session.duration), format: .time(pattern: .minuteSecond))
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
}
