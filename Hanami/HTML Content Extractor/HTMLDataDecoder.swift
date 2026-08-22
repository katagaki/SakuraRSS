import Foundation

/// Converts raw HTML response bytes to a string, honoring the server-declared
/// or document-declared character encoding before falling back to UTF-8 /
/// Windows-1252.  Required for CJK, Cyrillic, and older Western sites that
/// serve Shift-JIS, GB2312, EUC-KR, ISO-8859-1, or Windows-1252.
public nonisolated enum HTMLDataDecoder {

    public static func decode(_ data: Data, response: URLResponse?) -> String? {
        guard !data.isEmpty else { return nil }

        if let text = byteOrderMarkedText(in: data) { return text }
        if let text = utf16TextWithoutByteOrderMark(in: data) { return text }

        if let http = response as? HTTPURLResponse,
           let declared = http.textEncodingName,
           let text = text(from: data, ianaName: declared) {
            return text
        }

        if let declared = charsetFromMetaTags(in: data),
           let text = text(from: data, ianaName: declared) {
            return text
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        if let repaired = repairedUTF8Text(in: data) { return repaired }

        return String(data: data, encoding: .windowsCP1252)
    }

    private static func text(from data: Data, ianaName: String) -> String? {
        guard let encoding = encoding(fromIANAName: ianaName),
              let text = String(data: data, encoding: encoding),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func byteOrderMarkedText(in data: Data) -> String? {
        let bytes = [UInt8](data.prefix(4))
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            let body = data.dropFirst(3)
            return String(data: body, encoding: .utf8) ?? repairedUTF8Text(in: body)
        }
        if bytes.count >= 4, bytes[0] == 0xFF, bytes[1] == 0xFE,
           bytes[2] == 0x00, bytes[3] == 0x00 {
            return String(data: data.dropFirst(4), encoding: .utf32LittleEndian)
        }
        if bytes.count >= 4, bytes[0] == 0x00, bytes[1] == 0x00,
           bytes[2] == 0xFE, bytes[3] == 0xFF {
            return String(data: data.dropFirst(4), encoding: .utf32BigEndian)
        }
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xFE {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        return nil
    }

    /// UTF-16 without a BOM decodes as valid UTF-8 (the padding bytes are NUL),
    /// so the byte layout has to be sniffed before any declared charset is used.
    private static func utf16TextWithoutByteOrderMark(in data: Data) -> String? {
        let sample = [UInt8](data.prefix(512))
        guard sample.count >= 16 else { return nil }
        var evenNullCount = 0
        var oddNullCount = 0
        for (offset, byte) in sample.enumerated() where byte == 0 {
            if offset.isMultiple(of: 2) {
                evenNullCount += 1
            } else {
                oddNullCount += 1
            }
        }
        let threshold = sample.count / 4
        if oddNullCount > threshold, evenNullCount == 0 {
            return String(data: data, encoding: .utf16LittleEndian)
        }
        if evenNullCount > threshold, oddNullCount == 0 {
            return String(data: data, encoding: .utf16BigEndian)
        }
        return nil
    }

    /// Repairs a stream that is UTF-8 apart from a few malformed sequences, so a
    /// single truncated character does not send a whole document to CP1252.
    private static func repairedUTF8Text(in data: Data) -> String? {
        // swiftlint:disable:next optional_data_string_conversion
        let text = String(decoding: data, as: UTF8.self)
        guard !text.isEmpty else { return nil }
        var replacementCount = 0
        var scalarCount = 0
        for scalar in text.unicodeScalars {
            scalarCount += 1
            if scalar == "\u{FFFD}" { replacementCount += 1 }
        }
        guard replacementCount > 0 else { return text }
        let tolerance = max(4, scalarCount / 1000)
        return replacementCount <= tolerance ? text : nil
    }

    private static func encoding(fromIANAName name: String) -> String.Encoding? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cfName = trimmed as CFString
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(cfName)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }

    private static func charsetFromMetaTags(in data: Data) -> String? {
        let headLength = min(data.count, 4096)
        let prefix = data.prefix(headLength)
        guard let asciiHead = String(data: prefix, encoding: .isoLatin1) else {
            return nil
        }

        let patterns = [
            #"<meta[^>]+charset\s*=\s*["']?([\w\-]+)"#,
            #"<meta[^>]+content\s*=\s*["'][^"']*charset=([\w\-]+)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern, options: .caseInsensitive
            ) else { continue }
            // swiftlint:disable:next identifier_name
            let ns = asciiHead as NSString
            if let match = regex.firstMatch(
                in: asciiHead, range: NSRange(location: 0, length: ns.length)
            ), match.numberOfRanges >= 2 {
                let charset = ns.substring(with: match.range(at: 1))
                return charset
            }
        }
        return nil
    }
}
