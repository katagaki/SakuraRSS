import Foundation

/// Converts raw HTML response bytes to a string, honoring the server-declared
/// or document-declared character encoding before falling back to UTF-8 /
/// Windows-1252.  Required for CJK, Cyrillic, and older Western sites that
/// serve Shift-JIS, GB2312, EUC-KR, ISO-8859-1, or Windows-1252.
nonisolated enum HTMLDataDecoder {

    static func decode(_ data: Data, response: URLResponse?) -> String? {
        if let http = response as? HTTPURLResponse,
           let declared = http.textEncodingName,
           let encoding = encoding(fromIANAName: declared),
           let text = String(data: data, encoding: encoding),
           !text.isEmpty {
            return text
        }

        if let declared = charsetFromMetaTags(in: data),
           let encoding = encoding(fromIANAName: declared),
           let text = String(data: data, encoding: encoding),
           !text.isEmpty {
            return text
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return String(data: data, encoding: .windowsCP1252)
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
