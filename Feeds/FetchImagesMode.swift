import Foundation

/// Controls article image prefetching during feed refreshes.
nonisolated enum FetchImagesMode: String, CaseIterable, Sendable {
    case always
    case wifiOnly
    case off
}
