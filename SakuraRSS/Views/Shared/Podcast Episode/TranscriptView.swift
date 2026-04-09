import SwiftUI

struct TranscriptView: View {

    let segments: [TranscriptSegment]
    let currentTime: TimeInterval
    let isPlaying: Bool
    let onSeek: (TimeInterval) -> Void

    @State private var isAutoScrolling: Bool = true
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(segments) { segment in
                        segmentRow(segment)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .overlay(alignment: .bottom) {
                if !isAutoScrolling {
                    Button {
                        isAutoScrolling = true
                        if let activeID = activeSegmentID {
                            withAnimation(.smooth) {
                                proxy.scrollTo(activeID, anchor: .center)
                            }
                        }
                    } label: {
                        Label("Podcast.Transcript.FollowAlong", systemImage: "text.alignleft")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 12)
                }
            }
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
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func segmentRow(_ segment: TranscriptSegment) -> some View {
        let isActive = segment.id == activeSegmentID
        Text(segment.text)
            .font(.body)
            .fontWeight(isActive ? .semibold : .regular)
            .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onSeek(segment.start)
            }
            .animation(.smooth, value: isActive)
    }
}
