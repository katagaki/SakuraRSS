import Foundation

public extension String {
    /// Percent-encodes characters that would break a Markdown `[text](url)` link target,
    /// without disturbing existing `%XX` escapes in an already-partially-encoded URL.
    nonisolated var markdownLinkSafeURL: String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            switch character {
            case " ", "\t":
                result.append("%20")
            case "\n":
                result.append("%0A")
            case "\r":
                result.append("%0D")
            case "(":
                result.append("%28")
            case ")":
                result.append("%29")
            case "<":
                result.append("%3C")
            case ">":
                result.append("%3E")
            default:
                result.append(character)
            }
        }
        return result
    }
}
