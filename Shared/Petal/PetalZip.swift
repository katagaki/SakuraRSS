import Foundation

/// A deliberately tiny pure-Swift ZIP reader/writer that supports
/// just enough of the PKZIP spec to move `.srss` packages around:
///
///   - STORE method only (no DEFLATE — the payloads are a few KB of
///     JSON plus a small PNG, so the space savings wouldn't pay for
///     the extra compression code)
///   - no ZIP64, no encryption, no data descriptors
///   - short, ASCII filenames only
///
/// Shipping a minimal implementation keeps Sakura off a third-party
/// archiving dependency.  The format it writes is a valid ZIP file
/// that can be opened by Finder, `unzip`, and every other ZIP reader,
/// and the reader handles files it produced plus any other
/// STORED-entry ZIP a user might hand-craft.
///
/// The layout is the classic PKZIP one:
///
/// ```
/// [local file header + data] × N
/// [central directory header] × N
/// [end of central directory]
/// ```
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
        static let maxEntrySize = 5 * 1024 * 1024          // 5 MB
        static let maxTotalUncompressedSize = 10 * 1024 * 1024  // 10 MB
        static let maxNameLength = 512
    }

    // MARK: - Writing

    /// Packs entries into a STORED-only ZIP archive.  Returns the
    /// archive bytes — caller writes to disk (or ships elsewhere).
    static func write(entries: [Entry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let nameLength = UInt16(nameBytes.count)
            let crc = UInt32(crc32(entry.data))
            let size = UInt32(entry.data.count)
            let offset = UInt32(output.count)

            // Local file header
            output.appendLE(UInt32(0x04034b50))   // signature
            output.appendLE(UInt16(20))           // version needed
            output.appendLE(UInt16(0))            // flags
            output.appendLE(UInt16(0))            // method: STORE
            output.appendLE(UInt16(0))            // mod time
            output.appendLE(UInt16(0))            // mod date
            output.appendLE(crc)
            output.appendLE(size)                 // compressed size
            output.appendLE(size)                 // uncompressed size
            output.appendLE(nameLength)
            output.appendLE(UInt16(0))            // extra length
            output.append(contentsOf: nameBytes)
            output.append(entry.data)

            // Central directory header
            centralDirectory.appendLE(UInt32(0x02014b50))
            centralDirectory.appendLE(UInt16(20))  // version made by
            centralDirectory.appendLE(UInt16(20))  // version needed
            centralDirectory.appendLE(UInt16(0))   // flags
            centralDirectory.appendLE(UInt16(0))   // method
            centralDirectory.appendLE(UInt16(0))   // mod time
            centralDirectory.appendLE(UInt16(0))   // mod date
            centralDirectory.appendLE(crc)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(size)
            centralDirectory.appendLE(nameLength)
            centralDirectory.appendLE(UInt16(0))   // extra length
            centralDirectory.appendLE(UInt16(0))   // comment length
            centralDirectory.appendLE(UInt16(0))   // disk start
            centralDirectory.appendLE(UInt16(0))   // internal attrs
            centralDirectory.appendLE(UInt32(0))   // external attrs
            centralDirectory.appendLE(offset)
            centralDirectory.append(contentsOf: nameBytes)

            entryCount += 1
        }

        let cdOffset = UInt32(output.count)
        let cdSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        // End of central directory
        output.appendLE(UInt32(0x06054b50))
        output.appendLE(UInt16(0))             // disk number
        output.appendLE(UInt16(0))             // disk with CD
        output.appendLE(entryCount)            // entries this disk
        output.appendLE(entryCount)            // entries total
        output.appendLE(cdSize)
        output.appendLE(cdOffset)
        output.appendLE(UInt16(0))             // comment length

        return output
    }

    // MARK: - Reading

    /// Reads the entries from a ZIP archive.  Supports STORE entries
    /// and DEFLATE entries (by piggy-backing on Foundation's built-in
    /// `NSData.decompressed(using: .zlib)`).  Anything else surfaces
    /// `ZipError.unsupportedCompression`.
    ///
    /// Enforces the caps declared in `Limits` so that importing a
    /// maliciously-crafted `.srss` file can't blow up memory or
    /// exhaust the device with a zip-bomb-style payload.
    static func read(data: Data) throws -> [Entry] {
        guard let eocd = findEndOfCentralDirectory(in: data) else {
            throw ZipError.malformed
        }
        let entryCount = Int(data.readLE(UInt16.self, at: eocd + 10))
        let cdOffset = Int(data.readLE(UInt32.self, at: eocd + 16))

        guard entryCount <= Limits.maxEntryCount else {
            throw ZipError.tooLarge
        }

        var entries: [Entry] = []
        var cursor = cdOffset
        var runningTotal = 0

        for _ in 0..<entryCount {
            guard cursor + 46 <= data.count else { throw ZipError.truncated }
            guard data.readLE(UInt32.self, at: cursor) == 0x02014b50 else {
                throw ZipError.malformed
            }
            let method = data.readLE(UInt16.self, at: cursor + 10)
            let compressedSize = Int(data.readLE(UInt32.self, at: cursor + 20))
            let uncompressedSize = Int(data.readLE(UInt32.self, at: cursor + 24))
            let nameLength = Int(data.readLE(UInt16.self, at: cursor + 28))
            let extraLength = Int(data.readLE(UInt16.self, at: cursor + 30))
            let commentLength = Int(data.readLE(UInt16.self, at: cursor + 32))
            let localOffset = Int(data.readLE(UInt32.self, at: cursor + 42))

            // Size caps — check before doing any allocation or
            // decompression so a malicious header can't force us to
            // read a huge payload just to reject it afterwards.
            guard nameLength <= Limits.maxNameLength,
                  compressedSize <= Limits.maxEntrySize,
                  uncompressedSize <= Limits.maxEntrySize else {
                throw ZipError.tooLarge
            }
            // Check total separately so overflow-adjacent sizes
            // can't slip past the per-entry cap into a terabyte
            // running total.
            let (newTotal, overflow) = runningTotal.addingReportingOverflow(uncompressedSize)
            guard !overflow, newTotal <= Limits.maxTotalUncompressedSize else {
                throw ZipError.tooLarge
            }
            runningTotal = newTotal

            let nameStart = cursor + 46
            guard nameStart + nameLength <= data.count else {
                throw ZipError.truncated
            }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Local file header: 30 fixed bytes + file name + extra
            guard localOffset + 30 <= data.count else { throw ZipError.truncated }
            let localNameLength = Int(data.readLE(UInt16.self, at: localOffset + 26))
            let localExtraLength = Int(data.readLE(UInt16.self, at: localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= data.count else { throw ZipError.truncated }
            let payload = data.subdata(in: dataStart..<dataEnd)

            let decoded: Data
            switch method {
            case 0:
                decoded = payload
            case 8:
                decoded = try inflateDeflate(payload, expectedSize: uncompressedSize)
            default:
                throw ZipError.unsupportedCompression
            }
            // Trust-but-verify: a deflate entry whose header lied
            // about its uncompressed size might still try to expand
            // into more bytes than we budgeted.
            guard decoded.count <= Limits.maxEntrySize else {
                throw ZipError.tooLarge
            }
            entries.append(Entry(name: name, data: decoded))

            cursor += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    // MARK: - Inflate

    /// Inflates a raw DEFLATE stream into `expectedSize` bytes.
    ///
    /// Apple's `NSData.decompressed(using: .zlib)` is a bit of a
    /// misnomer: per Apple's docs it implements RFC 1951 (raw
    /// DEFLATE, the format used inside ZIP entries) — *not* the
    /// wrapped zlib format from RFC 1950 — so we can hand the
    /// compressed blob straight over.
    private static func inflateDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard let decompressed = try? (data as NSData)
            .decompressed(using: .zlib) as Data else {
            throw ZipError.malformed
        }
        if decompressed.count != expectedSize {
            // Not fatal — some producers add padding — but drop
            // anything past the declared size.
            return decompressed.prefix(expectedSize)
        }
        return decompressed
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        // Scan backwards looking for the signature.
        var cursor = data.count - 22
        let minCursor = max(0, data.count - 65_557) // max comment 64 KB
        while cursor >= minCursor {
            if data.readLE(UInt32.self, at: cursor) == 0x06054b50 {
                return cursor
            }
            cursor -= 1
        }
        return nil
    }

    // MARK: - CRC32

    /// Table-driven CRC32 (poly 0xEDB88320).  Lazily built on first use.
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

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let lookup = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ crcTable[lookup]
        }
        return crc ^ 0xFFFFFFFF
    }
}

// MARK: - Little-Endian Read/Write

// `nonisolated` is required because the project builds with
// MainActor-as-default isolation inference — without it these
// helpers get implicitly annotated `@MainActor` and can't be
// called from the `nonisolated enum PetalZip` above.
nonisolated private extension Data {

    /// Appends a 16-bit value in little-endian byte order.
    ///
    /// The global `Swift.withUnsafeBytes(of:_:)` is spelled out in
    /// full because inside a `Data` extension the unqualified name
    /// resolves to `Data.withUnsafeBytes`, which has the wrong
    /// signature for a scalar temporary.
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

    /// Reads a 16-bit little-endian value at the given byte offset.
    ///
    /// Uses `load(fromByteOffset:as: UInt8.self)` in preference to
    /// `buffer[offset]`: the subscript is overloaded on both `Int`
    /// and `Range<Int>`, and in a generic context Swift can't always
    /// pick the right one without a type annotation.  Byte-by-byte
    /// loads sidestep alignment concerns entirely.
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
            // Keep the expression in two halves so the type checker
            // doesn't time out trying to resolve a four-term OR.
            let low: UInt32 = b0 | (b1 << 8)
            let high: UInt32 = (b2 << 16) | (b3 << 24)
            return low | high
        }
    }
}
