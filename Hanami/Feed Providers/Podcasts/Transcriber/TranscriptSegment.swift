import Foundation

public nonisolated struct TranscriptSegment: Codable, Identifiable, Sendable, Hashable {
    public let id: Int
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String
}
