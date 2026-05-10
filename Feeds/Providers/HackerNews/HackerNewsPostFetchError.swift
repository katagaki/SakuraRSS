import Foundation

enum HackerNewsPostFetchError: Error {
    case invalidURL
    case badResponse
    case parseFailed
}
