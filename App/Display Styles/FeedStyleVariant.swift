import Foundation
import Hanami

enum FeedStyleVariant {
    case full(FeedImageLayout)
    case compact
}

enum FeedImageLayout {
    case carousel
    case single
    case grid
}
