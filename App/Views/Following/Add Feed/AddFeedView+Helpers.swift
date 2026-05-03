import SwiftUI

extension AddFeedView {

    func normalizeURL(_ input: String) -> String {
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return input
        }
        return "https://" + input
    }

    func extractDomain(from input: String) -> String {
        var cleaned = input
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[cleaned.startIndex..<slashIndex])
        }
        return cleaned
    }

    func addSuggestedFeed(_ site: SuggestedSite) {
        guard !addingURLs.contains(site.feedUrl),
              !addedURLs.contains(site.feedUrl) else { return }
        Task {
            addingURLs.insert(site.feedUrl)
            defer { addingURLs.remove(site.feedUrl) }
            do {
                _ = try await feedManager.addFeedFetchingMetadata(
                    url: site.feedUrl,
                    title: site.title,
                    siteURL: ""
                )
                addedURLs.insert(site.feedUrl)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
