import UIKit
import Hanami

struct SimilarArticleItem: Identifiable {
    let id: Int64
    let article: Article
    let feedName: String
    let isCircleIcon: Bool
    let sentiment: Double?
    let icon: UIImage?
}
