import Foundation

public struct DownloadProgress: Sendable {
    public var state: DownloadState
    public var progress: Double
    public var error: String?
}
