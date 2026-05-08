import Foundation

struct ListWidgetRequest {
    let listID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let currentPage: Int

    var markerKey: String {
        "listWidgetMarker_\(listID)_\(layout.rawValue)_\(columns)_\(currentPage)"
    }

    var cacheScope: String {
        "list_\(listID)_\(layout.rawValue)_\(columns)"
    }
}

struct ListWidgetLoadParams {
    let listID: Int64
    let layout: SingleFeedWidgetLayout
    let columns: Int
    let storedPage: Int
}
