import Foundation

public extension URLSession {

    /// Downloaded images are persisted in the SQLite image cache, so this
    /// session skips URLCache to avoid writing every image to disk twice.
    nonisolated static let sakuraImages: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()
}
