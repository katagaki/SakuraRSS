import SwiftUI

extension PodcastEpisodeView {

    func reloadCachedTranscript() {
        if let cached = try? DatabaseManager.shared.cachedTranscript(for: article.id),
           !cached.isEmpty {
            transcript = cached
        } else {
            transcript = nil
        }
    }

    /// Overlay button that re-enables transcript auto-scroll and jumps to the active segment.
    @ViewBuilder
    func followAlongOverlay(scrollProxy: ScrollViewProxy) -> some View {
        if showingTranscript, let transcript, !transcript.isEmpty, !isTranscriptAutoScrolling {
            Button {
                isTranscriptAutoScrolling = true
                UIApplication.shared.isIdleTimerDisabled = true
                if let active = activeTranscriptID(in: transcript) {
                    withAnimation(.smooth) {
                        scrollProxy.scrollTo(active, anchor: .center)
                    }
                }
            } label: {
                Text(String(localized: "Transcript.FollowAlong", table: "Podcast"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .compatibleGlassButtonStyle()
            .padding(.bottom, 12)
        }
    }

    /// Returns the id of the segment covering the current playback time.
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
