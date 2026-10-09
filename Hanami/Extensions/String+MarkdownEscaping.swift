import Foundation

nonisolated private let markdownEscapeRegex = try? NSRegularExpression(pattern: #"\\([\\`*_~\[\]])"#)

public extension String {

    nonisolated var markdownEscaped: String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            if "\\`*_~".contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }

    nonisolated var markdownUnescaped: String {
        guard contains("\\"), let markdownEscapeRegex else { return self }
        return markdownEscapeRegex.stringByReplacingMatches(
            in: self, range: NSRange(startIndex..., in: self), withTemplate: "$1"
        )
    }
}
