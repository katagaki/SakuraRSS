import Foundation
import Hanami

extension NewYouTubeClient {

    /// Parses an ISO BMFF `sidx` (Segment Index) box into HLS segments.
    /// `indexEndOffset` is the last byte offset of the `sidx` box within the
    /// media file, used to anchor the first media subsegment.
    static func parseSidx(_ data: Data, indexEndOffset: Int) -> [YouTubeHLSSegment]? {
        let bytes = [UInt8](data)
        var cursor = 0
        while cursor + 8 <= bytes.count {
            let boxSize = Int(readUInt32(bytes, at: cursor))
            let type = boxType(bytes, at: cursor + 4)
            if type == "sidx" {
                return parseSidxBox(bytes, boxStart: cursor, indexEndOffset: indexEndOffset)
            }
            guard boxSize > 0 else { return nil }
            cursor += boxSize
        }
        return nil
    }

    private static func parseSidxBox(
        _ bytes: [UInt8],
        boxStart: Int,
        indexEndOffset: Int
    ) -> [YouTubeHLSSegment]? {
        var position = boxStart + 8
        guard position < bytes.count else { return nil }
        let version = bytes[position]
        position += 4                 // version (1) + flags (3)
        position += 4                 // reference_ID
        let timescale = readUInt32(bytes, at: position)
        position += 4
        guard timescale > 0 else { return nil }

        var firstOffset: UInt64
        if version == 0 {
            position += 4             // earliest_presentation_time (32-bit)
            firstOffset = UInt64(readUInt32(bytes, at: position))
            position += 4
        } else {
            position += 8             // earliest_presentation_time (64-bit)
            firstOffset = readUInt64(bytes, at: position)
            position += 8
        }
        position += 2                 // reserved
        let referenceCount = Int(readUInt16(bytes, at: position))
        position += 2

        var segments: [YouTubeHLSSegment] = []
        var offset = indexEndOffset + 1 + Int(firstOffset)
        for _ in 0..<referenceCount {
            guard position + 12 <= bytes.count else { break }
            let referencedSize = Int(readUInt32(bytes, at: position) & 0x7FFF_FFFF)
            position += 4
            let durationTicks = readUInt32(bytes, at: position)
            position += 4
            position += 4             // SAP flags
            segments.append(
                YouTubeHLSSegment(
                    offset: offset,
                    length: referencedSize,
                    duration: Double(durationTicks) / Double(timescale)
                )
            )
            offset += referencedSize
        }
        return segments.isEmpty ? nil : segments
    }

    private static func boxType(_ bytes: [UInt8], at offset: Int) -> String {
        guard offset + 4 <= bytes.count else { return "" }
        return String(bytes: bytes[offset..<offset + 4], encoding: .ascii) ?? ""
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        guard offset + 2 <= bytes.count else { return 0 }
        return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return (UInt32(bytes[offset]) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
    }

    private static func readUInt64(_ bytes: [UInt8], at offset: Int) -> UInt64 {
        guard offset + 8 <= bytes.count else { return 0 }
        var value: UInt64 = 0
        for index in 0..<8 {
            value = (value << 8) | UInt64(bytes[offset + index])
        }
        return value
    }
}
