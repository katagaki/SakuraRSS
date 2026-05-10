import Foundation

/// Controls article image prefetching during feed refreshes.
public nonisolated enum FetchImagesMode: String, CaseIterable, Sendable {
    case always
    case wifiOnly
    case off
}
