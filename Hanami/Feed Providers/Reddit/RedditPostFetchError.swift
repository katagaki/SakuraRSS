import Foundation

public enum RedditPostFetchError: Error {
    case invalidURL
    case badResponse
    case rateLimited
    case parseFailed
}
