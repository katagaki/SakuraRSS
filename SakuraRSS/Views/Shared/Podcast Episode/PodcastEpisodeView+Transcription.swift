import SwiftUI

extension PodcastEpisodeView {

    /// Reloads the cached transcript from the database.
    func reloadCachedTranscript() {
        if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
           !cached.isEmpty {
            transcript = cached
        } else {
            transcript = nil
        }
    }

    /// A "follow along" button shown at the bottom of the scroll view when
    /// the user has scrolled away from the active transcript segment.
    /// Tapping it re-enables auto-scroll and jumps back to the active segment.
    @ViewBuilder
    func followAlongOverlay(scrollProxy: ScrollViewProxy) -> some View {
        if showingTranscript, let transcript, !transcript.isEmpty, !isTranscriptAutoScrolling {
            Button {
                isTranscriptAutoScrolling = true
                if let active = activeTranscriptID(in: transcript) {
                    withAnimation(.smooth) {
                        scrollProxy.scrollTo(active, anchor: .center)
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

    /// The id of the transcript segment that covers the current playback time.
    /// Uses binary search since segments are sorted by start time.
    func activeTranscriptID(in segments: [TranscriptSegment]) -> Int? {
        guard !segments.isEmpty else { return nil }
        let currentTime = AudioPlayer.shared.currentTime
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
}
