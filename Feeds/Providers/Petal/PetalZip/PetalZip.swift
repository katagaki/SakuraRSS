import Foundation

/// Minimal pure-Swift ZIP reader/writer for `.srss` packages.
/// Writes STORE only; reads STORE + DEFLATE. No ZIP64, encryption, or data descriptors.
nonisolated enum PetalZip {

    struct Entry: Sendable {
        var name: String
        var data: Data
    }

    enum ZipError: Error, Sendable {
        case malformed
        case unsupportedCompression
        case truncated
        /// Archive or entry exceeds caps that guard against zip-bomb payloads.
        case tooLarge
    }

    /// Hard caps enforced by `read(data:)` to defend against zip-bomb payloads.
    enum Limits {
        static let maxEntryCount = 16
        static let maxEntrySize = 5 * 1024 * 1024
        static let maxTotalUncompressedSize = 10 * 1024 * 1024
        static let maxNameLength = 512
    }

    // MARK: - Shared signatures

    enum Signatures {
        static let localFileHeader: UInt32 = 0x04034b50
        static let centralDirectoryHeader: UInt32 = 0x02014b50
        static let endOfCentralDirectory: UInt32 = 0x06054b50
    }
}
