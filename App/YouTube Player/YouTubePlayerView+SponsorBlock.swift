import SwiftUI
import Hanami

extension YouTubePlayerView {

    static func mergedSegments(_ segments: [SponsorSegment]) -> [SponsorSegment] {
        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var merged: [SponsorSegment] = []
        for segment in sorted {
            guard let previous = merged.last,
                  segment.startTime <= previous.endTime + 0.5 else {
                merged.append(segment)
                continue
            }
            merged[merged.count - 1] = SponsorSegment(
                UUID: previous.UUID,
                category: previous.category,
                startTime: previous.startTime,
                endTime: max(previous.endTime, segment.endTime)
            )
        }
        return merged
    }

    func checkSponsorSegments(at time: TimeInterval) {
        let previousTime = lastCheckedPlaybackTime
        lastCheckedPlaybackTime = time
        guard sponsorBlockEnabled, !isAd, !sponsorSegments.isEmpty else { return }
        for segment in sponsorSegments where !skippedSegmentIDs.contains(segment.id) {
            let isInsideSegment = time >= segment.startTime && time < segment.endTime
            // Time events are coalesced, so a short segment can be entered and
            // left between two of them without ever being reported as current.
            let passedStartSinceLastCheck = previousTime < segment.startTime
                && time >= segment.startTime
            guard isInsideSegment || passedStartSinceLastCheck else { continue }
            skippedSegmentIDs.insert(segment.id)
            let resumeTime = segment.endTime + 0.1
            guard resumeTime > time else { return }
            seek(to: resumeTime)
            lastCheckedPlaybackTime = resumeTime
            showSkippedMessage(for: segment)
            return
        }
    }

    private func showSkippedMessage(for segment: SponsorSegment) {
        let categoryName = SponsorBlockCategory(rawValue: segment.category)?
            .displayName ?? segment.category
        skippedSegmentMessage = String(
            localized: "YouTube.SponsorBlock.Skipped \(categoryName)", table: "Integrations"
        )
        skippedSegmentMessageTask?.cancel()
        skippedSegmentMessageTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation {
                skippedSegmentMessage = nil
            }
        }
    }
}
