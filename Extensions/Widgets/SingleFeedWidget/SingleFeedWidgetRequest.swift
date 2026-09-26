import Foundation
import Hanami

struct SingleFeedWidgetRequest {
    let feedID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let currentPage: Int
    let thumbnailMaxPixelSize: CGFloat

    var markerKey: String {
        "singleFeedMarker_\(feedID)_\(layout.rawValue)_\(columns)_\(currentPage)_\(Int(thumbnailMaxPixelSize))"
    }

    var cacheScope: String {
        "single_\(feedID)_\(layout.rawValue)_\(columns)_\(Int(thumbnailMaxPixelSize))"
    }
}

struct SingleFeedLoadParams {
    let feedID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let storedPage: Int
    let thumbnailMaxPixelSize: CGFloat
}
