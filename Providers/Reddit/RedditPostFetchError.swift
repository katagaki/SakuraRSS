import Foundation

enum RedditPostFetchError: Error {
    case invalidURL
    case badResponse
    case rateLimited
    case parseFailed
}
