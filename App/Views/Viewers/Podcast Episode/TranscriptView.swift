import SwiftUI

struct TranscriptView: View {

    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void
    /// Proxy from the enclosing scroll view; required so auto-follow doesn't nest scroll views.
    let scrollProxy: ScrollViewProxy
    @Binding var isAutoScrolling: Bool

    @State private var lastActiveID: Int?

    private var activeSegmentID: Int? {
        guard !segments.isEmpty else { return nil }
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
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                segmentText(segment)
                    .id(segment.id)
            }
        }
        .padding(.vertical, 12)
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
        Text(segment.text)
            .font(.body)
            .lineSpacing(4)
            .fontWeight(isActive ? .semibold : .regular)
            .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture {
                onSeek(segment.start)
            }
            .animation(.smooth, value: isActive)
    }
}
