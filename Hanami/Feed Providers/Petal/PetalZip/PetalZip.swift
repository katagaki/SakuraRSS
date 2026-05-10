import Foundation

/// Minimal pure-Swift ZIP reader/writer for `.srss` packages.
/// Writes STORE only; reads STORE + DEFLATE. No ZIP64, encryption, or data descriptors.
public nonisolated enum PetalZip {

    public struct Entry: Sendable {
        public var name: String
        public var data: Data
    }

    public enum ZipError: Error, Sendable {
        case malformed
        case unsupportedCompression
        case truncated
        /// Archive or entry exceeds caps that guard against zip-bomb payloads.
        case tooLarge
    }

    /// Hard caps enforced by `read(data:)` to defend against zip-bomb payloads.
    public enum Limits {
        public static let maxEntryCount = 16
        public static let maxEntrySize = 5 * 1024 * 1024
        public static let maxTotalUncompressedSize = 10 * 1024 * 1024
        public static let maxNameLength = 512
    }

    // MARK: - Shared signatures

    public enum Signatures {
        public static let localFileHeader: UInt32 = 0x04034b50
        public static let centralDirectoryHeader: UInt32 = 0x02014b50
        public static let endOfCentralDirectory: UInt32 = 0x06054b50
    }
}
