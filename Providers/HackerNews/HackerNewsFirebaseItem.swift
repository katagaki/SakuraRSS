import Foundation

nonisolated struct HackerNewsFirebaseItem: Decodable, Sendable {
    let id: Int
    // swiftlint:disable:next identifier_name
    let by: String?
    let text: String?
    let time: TimeInterval?
    let kids: [Int]?
    let deleted: Bool?
    let dead: Bool?
    let type: String?
}
