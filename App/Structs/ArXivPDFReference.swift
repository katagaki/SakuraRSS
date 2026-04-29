import Foundation

/// Navigation identifier for the arXiv PDF viewer.
struct ArXivPDFReference: Identifiable, Hashable {
    let url: URL
    let title: String
    var id: URL { url }
}
