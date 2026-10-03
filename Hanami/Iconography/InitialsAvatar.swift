import Foundation

public enum InitialsAvatar {

    public nonisolated static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
        let letters = words.prefix(2).compactMap(\.first).map(String.init)
        let result = letters.joined().uppercased()
        if result.isEmpty, let first = name.first {
            return String(first).uppercased()
        }
        return result
    }

    public nonisolated static func isGlyphBased(_ name: String) -> Bool {
        let letters = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_.,:;!?'\"()[]{}&@#/\\*+=<>|~`^$%"))
        let nonStandard = name.unicodeScalars.filter { !allowed.contains($0) }
        return nonStandard.count > letters.count / 2
    }

    public nonisolated static func backgroundHue(for name: String) -> CGFloat {
        let hash = name.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return CGFloat(abs(hash) % 360) / 360.0
    }
}
