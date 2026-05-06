import Foundation

/// Regex reject list for headline-summary inputs. Drops any article whose
/// title or snippet hits one of these patterns before it can reach the
/// model, so the safety classifier doesn't have to reject the whole batch
/// over a single sensitive phrase.
enum RejectPatterns {

    static let regexes: [NSRegularExpression] = {
        // swiftlint:disable line_length
        let sources: [String] = [
            #"(?i)\b((kill|slay|shoot|bomb|slaughter|maim|murder)(ed|ers?|ing|s)?|execut(e[ds]|er?s?|ing|ion(ers?)?)|(carnag|massacr|genocid)(ed|er?s?|ing)|(exterminat|annihilat)(e[ds]?|ors?|ing|ion)|genocid(al|ed|er?s?|ing)|perish(ed|ing|es)?|croak(ed|ing|s)?)\b"#,
            #"(?i)\b((pass(e[ds]|ing)?)\s+(away|on)|condolences|rest\s+in\s+peace|shot)\b"#,
            #"(?i)\b(dea(d|ths?)|deceas(e[ds]?|ing)|died|dying)\b"#,
            #"(?i)\b(lose|loses|lost|losing)\s+(our|her|his|their|your|my)\s+(life|lives)\b"#,
            #"(?i)\b(off(ed|ing|s)?|hang(ed|ing|s)?|hung|cut(ed|ting|s)?)\s+((my|one|them|him|her|your)self|themselves|me)\b"#,
            #"(?i)\b(took|tak(e[ns]?|ing))\s+(our|her|his|their|your|my)\s+(own\s+)?(life|lives)\b"#,
            #"(?i)\bsuicid(al|e[ds]?|ing)\b"#,
            #"(?i)\bmilitar(y|ies)\b"#
        ]
        // swiftlint:enable line_length
        return sources.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    static func matchesAny(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regexes.contains { regex in
            regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }
}
