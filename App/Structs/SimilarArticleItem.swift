import UIKit

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
    let isSocialFeed: Bool
    let sentiment: Double?
    let icon: UIImage?
}
