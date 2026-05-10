import Foundation

public enum HackerNewsPostFetchError: Error {
    case invalidURL
    case badResponse
    case parseFailed
}
