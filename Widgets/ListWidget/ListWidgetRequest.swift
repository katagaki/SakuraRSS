import Foundation
import Hanami

struct ListWidgetRequest {
    let listID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let currentPage: Int
    let thumbnailMaxPixelSize: CGFloat

    var markerKey: String {
        "listWidgetMarker_\(listID)_\(layout.rawValue)_\(columns)_\(currentPage)"
    }

    var cacheScope: String {
        "list_\(listID)_\(layout.rawValue)_\(columns)_\(Int(thumbnailMaxPixelSize))"
    }
}

struct ListWidgetLoadParams {
    let listID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let storedPage: Int
    let thumbnailMaxPixelSize: CGFloat
}
