import Foundation
import Hanami

/// One media subsegment of a synthesized HLS playlist, described as a byte
/// range into the backing media file plus its presentation duration.
nonisolated struct YouTubeHLSSegment: Sendable {
    let offset: Int
    let length: Int
    let duration: Double
}
