import Foundation

nonisolated extension PetalZip {

    // MARK: - CRC32

    /// Table-driven CRC32 (polynomial 0xEDB88320, reflected).
    ///
    /// This is the checksum that PKZIP entries use to let readers
    /// verify entry integrity; it is **not** a cryptographic hash
    /// and must not be used for integrity-sensitive purposes.
    ///
    /// The table is built lazily on first access inside a static
    /// `let` initializer — no thread-safety concerns because
    /// static lets on top-level types are initialised exactly once
    /// under `dispatch_once` semantics.
    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let lookup = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[lookup]
        }
        return crc ^ 0xFFFFFFFF
    }

    /// Precomputed 256-entry lookup table for the reflected
    /// CRC32 polynomial 0xEDB88320.
    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for index in 0..<256 {
            var value = UInt32(index)
            for _ in 0..<8 {
                if value & 1 == 1 {
                    value = 0xEDB88320 ^ (value >> 1)
                } else {
                    value >>= 1
                }
            }
            table[index] = value
        }
        return table
    }()
}
