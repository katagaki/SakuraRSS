import Foundation
import UIKit

public extension FeedManager {

    // MARK: - Acronym Icons

    func generateAcronymIcon(feedID: Int64, title: String) {
        let database = database
        Task.detached(priority: .utility) {
            guard let image = InitialsAvatar.renderToImage(name: title),
                  let pngData = image.pngData() else { return }
            try? database.updateFeedAcronymIcon(id: feedID, data: pngData)
        }
    }

    func regenerateAllAcronymIcons() {
        let entries = feeds.map { ($0.id, $0.title) }
        let database = database
        Task.detached(priority: .utility) {
            for (id, title) in entries {
                guard let image = InitialsAvatar.renderToImage(name: title),
                      let pngData = image.pngData() else { continue }
                try? database.updateFeedAcronymIcon(id: id, data: pngData)
            }
        }
    }

}
