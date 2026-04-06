import SwiftUI

struct SeekBarView: View {

    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    var isDisabled: Bool = false
    var segments: [(start: Double, end: Double)] = []
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0

    private var displayTime: TimeInterval {
        isDragging ? dragTime : currentTime
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(displayTime / duration)
    }

    private var remainingTime: TimeInterval {
        max(duration - displayTime, 0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Track
            GeometryReader { geometry in
                let trackWidth = geometry.size.width
                let thumbX = progress * trackWidth

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.tertiary)
                        .frame(height: isDragging ? 8 : 6)

                    // Sponsor segment markers
                    if duration > 0 {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            let startFraction = CGFloat(segment.start / duration)
                            let endFraction = CGFloat(segment.end / duration)
                            let segmentWidth = max((endFraction - startFraction) * trackWidth, 2)
                            Capsule()
                                .fill(Color.green.opacity(0.5))
                                .frame(
                                    width: segmentWidth,
                                    height: isDragging ? 8 : 6
                                )
                                .offset(x: startFraction * trackWidth)
                        }
                    }

                    // Filled track
                    Capsule()
                        .fill(.tint)
                        .frame(width: max(thumbX, 0), height: isDragging ? 8 : 6)
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard !isDisabled else { return }
                            if !isDragging {
                                isDragging = true
                                dragTime = currentTime
                            }
                            let fraction = max(0, min(value.location.x / trackWidth, 1))
                            dragTime = TimeInterval(fraction) * duration
                        }
                        .onEnded { _ in
                            guard !isDisabled else { return }
                            onSeek(dragTime)
                            currentTime = dragTime
                            isDragging = false
                        }
                )
                .opacity(isDisabled ? 0.4 : 1.0)
            }
            .frame(height: 16)
            .animation(.easeInOut(duration: 0.15), value: isDragging)

            // Time labels
            HStack {
                Text(formatTime(displayTime))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text("-\(formatTime(remainingTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
