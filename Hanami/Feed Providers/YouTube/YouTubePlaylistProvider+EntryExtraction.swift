import Foundation

public extension YouTubePlaylistProvider {

    static func extractVideoEntries(
        fromBrowseRenderer renderer: [String: Any]
    ) -> [[String: Any]]? {
        guard let tabs = renderer["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let tabContent = tabRenderer["content"] as? [String: Any],
              let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]],
              let firstSection = sectionContents.first,
              let itemSection = firstSection["itemSectionRenderer"] as? [String: Any],
              let itemContents = itemSection["contents"] as? [[String: Any]],
              let firstItem = itemContents.first,
              let playlistVideoList = firstItem["playlistVideoListRenderer"] as? [String: Any],
              let videoEntries = playlistVideoList["contents"] as? [[String: Any]] else {
            return nil
        }
        return videoEntries
    }
}
