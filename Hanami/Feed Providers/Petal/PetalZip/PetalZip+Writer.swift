import Foundation

public nonisolated extension PetalZip {

    // MARK: - Writing

    /// Packs entries into a STORED-only ZIP archive and returns the bytes.
    static func write(entries: [Entry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var entryCount: UInt16 = 0

        for entry in entries {
            let nameBytes = Array(entry.name.utf8)
            let nameLength = UInt16(nameBytes.count)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)
            let offset = UInt32(output.count)

            appendLocalFileHeader(
                to: &output,
                nameBytes: nameBytes,
                nameLength: nameLength,
                crc: crc,
                size: size
            )
            output.append(entry.data)

            appendCentralDirectoryHeader(
                to: &centralDirectory,
                entry: CentralDirectoryEntry(
                    nameBytes: nameBytes,
                    nameLength: nameLength,
                    crc: crc,
                    size: size,
                    localHeaderOffset: offset
                )
            )

            entryCount += 1
        }

        let cdOffset = UInt32(output.count)
        let cdSize = UInt32(centralDirectory.count)
        output.append(centralDirectory)

        appendEndOfCentralDirectory(
            to: &output,
            entryCount: entryCount,
            cdSize: cdSize,
            cdOffset: cdOffset
        )

        return output
    }

    // MARK: - Headers

    private static func appendLocalFileHeader(
        to output: inout Data,
        nameBytes: [UInt8],
        nameLength: UInt16,
        crc: UInt32,
        size: UInt32
    ) {
        output.appendLE(Signatures.localFileHeader)
        output.appendLE(UInt16(20))   // version needed
        output.appendLE(UInt16(0))    // flags
        output.appendLE(UInt16(0))    // method: STORE
        output.appendLE(UInt16(0))    // mod time
        output.appendLE(UInt16(0))    // mod date
        output.appendLE(crc)
        output.appendLE(size)         // compressed size
        output.appendLE(size)         // uncompressed size
        output.appendLE(nameLength)
        output.appendLE(UInt16(0))    // extra length
        output.append(contentsOf: nameBytes)
    }

    private struct CentralDirectoryEntry {
        public let nameBytes: [UInt8]
        public let nameLength: UInt16
        public let crc: UInt32
        public let size: UInt32
        public let localHeaderOffset: UInt32
    }

    private static func appendCentralDirectoryHeader(
        to centralDirectory: inout Data,
        entry: CentralDirectoryEntry
    ) {
        let nameBytes = entry.nameBytes
        let nameLength = entry.nameLength
        let crc = entry.crc
        let size = entry.size
        let localHeaderOffset = entry.localHeaderOffset
        centralDirectory.appendLE(Signatures.centralDirectoryHeader)
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
        centralDirectory.appendLE(localHeaderOffset)
        centralDirectory.append(contentsOf: nameBytes)
    }

    private static func appendEndOfCentralDirectory(
        to output: inout Data,
        entryCount: UInt16,
        cdSize: UInt32,
        cdOffset: UInt32
    ) {
        output.appendLE(Signatures.endOfCentralDirectory)
        output.appendLE(UInt16(0))       // disk number
        output.appendLE(UInt16(0))       // disk with CD
        output.appendLE(entryCount)      // entries this disk
        output.appendLE(entryCount)      // entries total
        output.appendLE(cdSize)
        output.appendLE(cdOffset)
        output.appendLE(UInt16(0))       // comment length
    }
}
