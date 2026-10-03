import Foundation

nonisolated struct AppStoreIconLookup: Decodable {
    let results: [Artwork]

    nonisolated struct Artwork: Decodable {
        let trackId: Int
        let artworkUrl60: URL?
        let artworkUrl100: URL?
        let artworkUrl512: URL?

        var iconURL: URL? {
            artworkUrl512 ?? artworkUrl100 ?? artworkUrl60
        }
    }
}
