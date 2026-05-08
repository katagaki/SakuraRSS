import Foundation

struct SingleFeedWidgetRequest {
    let feedID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let currentPage: Int

    var markerKey: String {
        "singleFeedMarker_\(feedID)_\(layout.rawValue)_\(columns)_\(currentPage)"
    }

    var cacheScope: String {
        "single_\(feedID)_\(layout.rawValue)_\(columns)"
    }
}

struct SingleFeedLoadParams {
    let feedID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let storedPage: Int
}
