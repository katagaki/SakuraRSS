import SwiftUI

enum SeekBarLabelLayout {
    case below
    case inline
    case hidden
}

struct SeekBarView: View {

    let currentTime: TimeInterval
    let duration: TimeInterval
    var isDisabled: Bool = false
    var segments: [(start: Double, end: Double)] = []
    var labelLayout: SeekBarLabelLayout = .below
    let onSeek: (TimeInterval) -> Void

    @State private var isDragging = false
    @State private var dragTime: TimeInterval = 0
    /// Holds the seek target between drag-end and the parent's `currentTime`
    /// catching up, so the bar doesn't snap back to the pre-seek position.
    @State private var pendingSeekTarget: TimeInterval?

    private var displayTime: TimeInterval {
        if isDragging { return dragTime }
        if let pendingSeekTarget { return pendingSeekTarget }
        return currentTime
    }

    private var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(displayTime / duration)
    }

    private var remainingTime: TimeInterval {
        max(duration - displayTime, 0)
    }

    var body: some View {
        Group {
            switch labelLayout {
            case .below:
                VStack(spacing: 8) {
                    track
                    HStack {
                        leadingLabel
                        Spacer()
                        trailingLabel
                    }
                }
            case .inline:
                HStack(spacing: 12) {
                    leadingLabel
                    track
                    trailingLabel
                }
            case .hidden:
                track
            }
        }
        .onChange(of: currentTime) { _, newTime in
            if let target = pendingSeekTarget, abs(newTime - target) < 0.75 {
                pendingSeekTarget = nil
            }
        }
    }

    private var track: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let thumbX = progress * trackWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.tertiary)
                    .frame(height: isDragging ? 8 : 6)

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

                Capsule()
                    .fill(.tint)
                    .frame(width: max(thumbX, 0), height: isDragging ? 8 : 6)
            }
            .frame(height: 16)
            .contentShape(.rect)
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
                        if abs(dragTime - currentTime) >= 0.5 {
                            pendingSeekTarget = dragTime
                        }
                        onSeek(dragTime)
                        isDragging = false
                    }
            )
            .opacity(isDisabled ? 0.4 : 1.0)
        }
        .frame(height: 16)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }

    private var leadingLabel: some View {
        Text(formatTime(displayTime))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var trailingLabel: some View {
        Text("-\(formatTime(remainingTime))")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
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
