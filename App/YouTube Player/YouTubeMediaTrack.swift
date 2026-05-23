import Foundation

nonisolated struct YouTubeCaptionTrack: Identifiable, Equatable, Sendable {
    let code: String
    let name: String
    let isSelected: Bool

    var id: String { code }
}
