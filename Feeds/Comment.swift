import Foundation

nonisolated struct Comment: Identifiable, Hashable, Sendable {
    let id: Int64
    let articleID: Int64
    var rank: Int
    var author: String
    var body: String
    var createdDate: Date?
    var sourceURL: String?
}
