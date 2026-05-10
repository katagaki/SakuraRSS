import Foundation

public nonisolated struct HackerNewsFirebaseItem: Decodable, Sendable {
    public let id: Int
    // swiftlint:disable:next identifier_name
    public let by: String?
    public let text: String?
    public let time: TimeInterval?
    public let kids: [Int]?
    public let deleted: Bool?
    public let dead: Bool?
    public let type: String?
}
