import Foundation

struct DiscoverEntitySection: Identifiable {
    let name: String
    let types: [String]
    let articles: [Article]

    var id: String { name }
}
