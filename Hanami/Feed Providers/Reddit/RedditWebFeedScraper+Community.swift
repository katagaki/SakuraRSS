import Foundation
import WebKit

private struct RedditWebCommunitySnapshot: Decodable {
    let iconURL: String?
    let challenge: Bool
}

public extension RedditWebFeedScraper {
    static func communityIcon(subreddit: String) async -> String? {
        let key = subreddit.lowercased()
        if let cached = communityIcons[key] { return cached }
        if let pending = communityIconTasks[key] { return await pending.value }
        let task = Task {
            try? await RedditWebFeedScraper().fetchCommunityIcon(subreddit: subreddit)
        }
        communityIconTasks[key] = task
        let iconURL = await task.value
        communityIconTasks[key] = nil
        communityIcons[key] = iconURL
        return iconURL
    }
}

private extension RedditWebFeedScraper {
    static var communityIcons: [String: String] = [:]
    static var communityIconTasks: [String: Task<String?, Never>] = [:]

    func fetchCommunityIcon(subreddit: String) async throws -> String? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.reddit.com"
        components.path = "/r/\(subreddit)/"
        guard let url = components.url else { return nil }
        defer {
            webView.stopLoading()
            webView.navigationDelegate = nil
        }
        try await load(url)
        let script = #"""
        (() => {
          const image = document.querySelector('#subreddit-icon-img img');
          const bodyText = document.body.innerText.toLowerCase();
          return JSON.stringify({iconURL: image?.getAttribute('src') || null,
            challenge: !!document.querySelector('form[action*="challenge"]') ||
              bodyText.includes('prove you are human') || document.title.toLowerCase() === 'blocked'});
        })()
        """#
        for _ in 0..<10 {
            let snapshot: RedditWebCommunitySnapshot = try await evaluateSnapshot(script)
            if !snapshot.challenge, let iconURL = snapshot.iconURL,
               let icon = URL(string: iconURL, relativeTo: url)?.absoluteURL,
               ["http", "https"].contains(icon.scheme?.lowercased() ?? "") {
                return icon.absoluteString
            }
            try await Task.sleep(for: .seconds(1))
        }
        return nil
    }
}
