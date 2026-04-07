import SwiftUI

extension YouTubePlayerView {

    func checkSponsorSegments(at time: TimeInterval) {
        guard sponsorBlockEnabled, !isAd, !sponsorSegments.isEmpty else { return }
        for segment in sponsorSegments {
            if time >= segment.startTime && time < segment.endTime
                && !skippedSegmentIDs.contains(segment.id) {
                skippedSegmentIDs.insert(segment.id)
                seek(to: segment.endTime + 0.1)
                let categoryName = SponsorBlockCategory(rawValue: segment.category)?
                    .displayName ?? segment.category
                skippedSegmentMessage = String(
                    localized: "YouTube.SponsorBlock.Skipped \(categoryName)"
                )
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        skippedSegmentMessage = nil
                    }
                }
                return
            }
        }
    }
}
