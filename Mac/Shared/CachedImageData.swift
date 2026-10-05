import Foundation
import Hanami

/// Reads an image from the database's image cache, as iOS does, before going to the network.
enum CachedImageData {

    @concurrent nonisolated static func load(_ url: URL) async -> Data? {
        if let cached = try? DatabaseManager.shared.cachedImageData(for: url.absoluteString) {
            return cached
        }
        return try? await URLSession.shared.data(for: .sakuraImage(url: url)).0
    }
}
