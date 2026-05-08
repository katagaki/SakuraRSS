import SwiftUI

extension NewYouTubePlayerView {

    func checkSponsorSegments(at time: TimeInterval) {
        guard sponsorBlockEnabled, !sponsorSegments.isEmpty else { return }
        for segment in sponsorSegments {
            if time >= segment.startTime && time < segment.endTime
                && !skippedSegmentIDs.contains(segment.id) {
                skippedSegmentIDs.insert(segment.id)
                playback.seek(to: segment.endTime + 0.1)
                let categoryName = SponsorBlockCategory(rawValue: segment.category)?
                    .displayName ?? segment.category
                skippedSegmentMessage = String(
                    localized: "YouTube.SponsorBlock.Skipped \(categoryName)", table: "Integrations"
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
