import Foundation

// MARK: - Little-Endian Read/Write

/// Byte-level helpers the ZIP writer and reader share.
///
/// `nonisolated` is required because the project builds with
/// MainActor-as-default isolation inference — without it these
/// helpers get implicitly annotated `@MainActor` and can't be
/// called from the `nonisolated enum PetalZip` above.  Keeping the
/// helpers file-internal (rather than exporting them as generic
/// Foundation extensions) keeps the blast radius small: if future
/// binary formats need similar helpers they should get their own
/// copy rather than accidentally binding to these.
nonisolated extension Data {

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
    /// and `Range<Int>`, and in a generic context Swift can't
    /// always pick the right one without a type annotation.
    /// Byte-by-byte loads sidestep alignment concerns entirely.
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
