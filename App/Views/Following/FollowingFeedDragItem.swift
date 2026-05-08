import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    nonisolated static let sakuraFeedDrag = UTType(exportedAs: "app.sakura.feed-drag")
}

struct FollowingFeedDragItem: Codable, Transferable {

    let feedID: Int64

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .sakuraFeedDrag)
    }
}
