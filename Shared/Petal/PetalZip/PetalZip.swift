import Foundation

/// A deliberately tiny pure-Swift ZIP reader/writer that supports
/// just enough of the PKZIP spec to move `.srss` packages around:
///
///   - STORE method only for writing; STORE + DEFLATE for reading
///   - no ZIP64, no encryption, no data descriptors
///   - short, ASCII filenames only
///
/// Shipping a minimal implementation keeps Sakura off a third-party
/// archiving dependency.  The format it writes is a valid ZIP file
/// that can be opened by Finder, `unzip`, and every other ZIP
/// reader, and the reader handles files it produced plus any other
/// STORED-or-DEFLATED-entry ZIP a user might hand-craft.
///
/// The layout is the classic PKZIP one:
///
/// ```
/// [local file header + data] × N
/// [central directory header] × N
/// [end of central directory]
/// ```
///
/// The implementation is split across several files in this folder
/// by responsibility: `+Writer` produces archives, `+Reader` parses
/// them, `+CRC32` provides the integrity checksum, and
/// `Data+LittleEndian` hosts the byte-order helpers the other files
/// lean on.  This file hosts only the public type, nested value
/// types, and shared limits.
nonisolated enum PetalZip {

    struct Entry: Sendable {
        var name: String
        var data: Data
    }

    enum ZipError: Error, Sendable {
        case malformed
        case unsupportedCompression
        case truncated
        /// The archive — or a single entry inside it — exceeds the
        /// hard caps we enforce on import to defend against "zip
        /// bomb" payloads that try to exhaust memory by expanding
        /// kilobytes of deflate into gigabytes of decoded output.
        case tooLarge
    }

    /// Hard caps enforced by `read(data:)` when importing a `.srss`
    /// package.  Legitimate packages are a few KB of JSON plus a
    /// small PNG icon, so these limits leave several orders of
    /// magnitude of headroom while still bounding memory use to
    /// something safe if a malicious package tries to fill it.
    enum Limits {
        static let maxEntryCount = 16
        static let maxEntrySize = 5 * 1024 * 1024              // 5 MB
        static let maxTotalUncompressedSize = 10 * 1024 * 1024 // 10 MB
        static let maxNameLength = 512
    }

    // MARK: - Shared signatures

    /// ZIP header signatures in little-endian form.
    /// Spelled out centrally so writer and reader agree.
    enum Signatures {
        static let localFileHeader: UInt32 = 0x04034b50
        static let centralDirectoryHeader: UInt32 = 0x02014b50
        static let endOfCentralDirectory: UInt32 = 0x06054b50
    }
}
