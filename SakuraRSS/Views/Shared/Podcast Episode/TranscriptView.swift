import SwiftUI

struct TranscriptView: View {

    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void
    /// Proxy for the enclosing scroll view. Required so the transcript can
    /// auto-follow without nesting its own ScrollView inside the parent's.
    let scrollProxy: ScrollViewProxy
    @Binding var isAutoScrolling: Bool

    @State private var lastActiveID: Int?

    private var activeSegmentID: Int? {
        guard !segments.isEmpty else { return nil }
        // Binary search for the latest segment whose start is <= currentTime.
        var low = 0
        var high = segments.count - 1
        var result: Int?
        while low <= high {
            let mid = (low + high) / 2
            if segments[mid].start <= currentTime {
                result = segments[mid].id
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    var body: some View {
        // Render segments as continuous prose — one flowing paragraph — rather
        // than a list of timestamped blocks. Each segment is still tappable to
        // seek, and the active segment is emphasized with weight + color.
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(segments) { segment in
                segmentText(segment)
                    .id(segment.id)
            }
        }
        .padding(.vertical, 12)
        .simultaneousGesture(
            DragGesture(minimumDistance: 8).onChanged { _ in
                if isAutoScrolling {
                    isAutoScrolling = false
                }
            }
        )
        .onChange(of: activeSegmentID) { _, newID in
            guard isAutoScrolling, let newID else { return }
            if newID != lastActiveID {
                lastActiveID = newID
                withAnimation(.smooth) {
                    scrollProxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func segmentText(_ segment: TranscriptSegment) -> some View {
        let isActive = segment.id == activeSegmentID
        Text(segment.text + " ")
            .font(.body)
            .fontWeight(isActive ? .semibold : .regular)
            .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                onSeek(segment.start)
            }
            .animation(.smooth, value: isActive)
    }
}
