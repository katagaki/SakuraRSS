import Foundation

nonisolated struct TranscriptSegment: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}
