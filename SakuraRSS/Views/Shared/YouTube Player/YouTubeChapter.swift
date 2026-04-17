import Foundation

struct YouTubeChapter: Identifiable, Equatable {
    let id: Int
    let title: String
    let startTime: TimeInterval
}

extension YouTubeChapter {
    var formattedTimestamp: String {
        let total = Int(startTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
