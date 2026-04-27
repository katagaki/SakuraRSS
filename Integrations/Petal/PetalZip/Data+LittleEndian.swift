import Foundation

// MARK: - Little-Endian Read/Write

/// Byte-level helpers the ZIP writer and reader share.
/// `nonisolated` so they stay callable from the nonisolated `PetalZip` enum.
nonisolated extension Data {

    /// Appends a 16-bit value in little-endian byte order.
    /// Uses `Swift.withUnsafeBytes` explicitly to avoid `Data.withUnsafeBytes`.
    mutating func appendLE(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { bytes in
            self.append(contentsOf: bytes)
        }
    }

    mutating func appendLE(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { bytes in
            self.append(contentsOf: bytes)
        }
    }

    // swiftlint:disable identifier_name
    /// Reads a 16-bit little-endian value at the given byte offset.
    /// Loads byte-by-byte to sidestep alignment concerns.
    func readLE(_: UInt16.Type, at offset: Int) -> UInt16 {
        self.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> UInt16 in
            let b0 = UInt16(buffer.load(fromByteOffset: offset, as: UInt8.self))
            let b1 = UInt16(buffer.load(fromByteOffset: offset + 1, as: UInt8.self))
            return b0 | (b1 << 8)
        }
    }

    func readLE(_: UInt32.Type, at offset: Int) -> UInt32 {
        self.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> UInt32 in
            let b0 = UInt32(buffer.load(fromByteOffset: offset, as: UInt8.self))
            let b1 = UInt32(buffer.load(fromByteOffset: offset + 1, as: UInt8.self))
            let b2 = UInt32(buffer.load(fromByteOffset: offset + 2, as: UInt8.self))
            let b3 = UInt32(buffer.load(fromByteOffset: offset + 3, as: UInt8.self))
            // Split into two halves to avoid type-checker timeout on the four-term OR.
            let low: UInt32 = b0 | (b1 << 8)
            let high: UInt32 = (b2 << 16) | (b3 << 24)
            return low | high
        }
    }
    // swiftlint:enable identifier_name
}
