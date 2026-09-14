import Foundation

/// Decides whether omnibox text is a site address, which is what lets one field
/// both search subscriptions and subscribe to something new.
enum BrowserAddressInput {

    static func siteHost(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
        if let scheme = URL(string: trimmed)?.scheme, scheme == "http" || scheme == "https" {
            return URL(string: trimmed)?.host
        }
        guard let dotIndex = trimmed.lastIndex(of: "."),
              trimmed.distance(from: dotIndex, to: trimmed.endIndex) > 2,
              !trimmed.hasPrefix(".") else { return nil }
        return URL(string: "https://\(trimmed)")?.host
    }

    static func normalizedURLString(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard siteHost(from: trimmed) != nil else { return nil }
        if trimmed.lowercased().hasPrefix("http") { return trimmed }
        return "https://\(trimmed)"
    }
}
