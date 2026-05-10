import Foundation

nonisolated extension PetalZip {

    // MARK: - Reading

    /// Reads entries from a ZIP archive (STORE or DEFLATE). Enforces `Limits`.
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
            let header = try parseCentralDirectoryEntry(in: data, at: cursor)
            try enforceLimits(header: header, runningTotal: &runningTotal)

            let name = try readEntryName(in: data, header: header, at: cursor)
            let payload = try readEntryPayload(in: data, header: header)
            let decoded = try decodePayload(payload, header: header)

            // A deflate entry can expand past its declared size; re-check after decoding.
            guard decoded.count <= Limits.maxEntrySize else {
                throw ZipError.tooLarge
            }
            entries.append(Entry(name: name, data: decoded))

            cursor += 46 + header.nameLength + header.extraLength + header.commentLength
        }
        return entries
    }

    // MARK: - Central directory parsing

    private struct CentralDirectoryEntry {
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let nameLength: Int
        let extraLength: Int
        let commentLength: Int
        let localOffset: Int
    }

    private static func parseCentralDirectoryEntry(
        in data: Data,
        at cursor: Int
    ) throws -> CentralDirectoryEntry {
        guard cursor + 46 <= data.count else { throw ZipError.truncated }
        guard data.readLE(UInt32.self, at: cursor) == Signatures.centralDirectoryHeader else {
            throw ZipError.malformed
        }
        return CentralDirectoryEntry(
            method: data.readLE(UInt16.self, at: cursor + 10),
            compressedSize: Int(data.readLE(UInt32.self, at: cursor + 20)),
            uncompressedSize: Int(data.readLE(UInt32.self, at: cursor + 24)),
            nameLength: Int(data.readLE(UInt16.self, at: cursor + 28)),
            extraLength: Int(data.readLE(UInt16.self, at: cursor + 30)),
            commentLength: Int(data.readLE(UInt16.self, at: cursor + 32)),
            localOffset: Int(data.readLE(UInt32.self, at: cursor + 42))
        )
    }

    // MARK: - Caps

    private static func enforceLimits(
        header: CentralDirectoryEntry,
        runningTotal: inout Int
    ) throws {
        guard header.nameLength <= Limits.maxNameLength,
              header.compressedSize <= Limits.maxEntrySize,
              header.uncompressedSize <= Limits.maxEntrySize else {
            throw ZipError.tooLarge
        }
        // Use overflow-reporting add so oversized sizes can't wrap past the total cap.
        let (newTotal, overflow) = runningTotal
            .addingReportingOverflow(header.uncompressedSize)
        guard !overflow, newTotal <= Limits.maxTotalUncompressedSize else {
            throw ZipError.tooLarge
        }
        runningTotal = newTotal
    }

    // MARK: - Payload extraction

    private static func readEntryName(
        in data: Data,
        header: CentralDirectoryEntry,
        at cursor: Int
    ) throws -> String {
        let nameStart = cursor + 46
        guard nameStart + header.nameLength <= data.count else {
            throw ZipError.truncated
        }
        let nameData = data.subdata(in: nameStart..<(nameStart + header.nameLength))
        return String(data: nameData, encoding: .utf8) ?? ""
    }

    private static func readEntryPayload(
        in data: Data,
        header: CentralDirectoryEntry
    ) throws -> Data {
        guard header.localOffset + 30 <= data.count else {
            throw ZipError.truncated
        }
        let localNameLength = Int(data.readLE(UInt16.self, at: header.localOffset + 26))
        let localExtraLength = Int(data.readLE(UInt16.self, at: header.localOffset + 28))
        let dataStart = header.localOffset + 30 + localNameLength + localExtraLength
        let dataEnd = dataStart + header.compressedSize
        guard dataEnd <= data.count else { throw ZipError.truncated }
        return data.subdata(in: dataStart..<dataEnd)
    }

    private static func decodePayload(
        _ payload: Data,
        header: CentralDirectoryEntry
    ) throws -> Data {
        switch header.method {
        case 0:
            return payload
        case 8:
            return try inflateDeflate(payload, expectedSize: header.uncompressedSize)
        default:
            throw ZipError.unsupportedCompression
        }
    }

    // MARK: - Inflate

    /// Inflates a raw DEFLATE stream into `expectedSize` bytes.
    /// `NSData.decompressed(using: .zlib)` is actually raw DEFLATE (RFC 1951), not zlib-wrapped.
    private static func inflateDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard let decompressed = try? (data as NSData)
            .decompressed(using: .zlib) as Data else {
            throw ZipError.malformed
        }
        if decompressed.count != expectedSize {
            // Some producers pad; trim to the declared size.
            return decompressed.prefix(expectedSize)
        }
        return decompressed
    }

    // MARK: - EOCD Scanning

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else { return nil }
        var cursor = data.count - 22
        let minCursor = max(0, data.count - 65_557) // max comment 64 KB
        while cursor >= minCursor {
            if data.readLE(UInt32.self, at: cursor) == Signatures.endOfCentralDirectory {
                return cursor
            }
            cursor -= 1
        }
        return nil
    }
}
