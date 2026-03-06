import Foundation
import WebKit

// MARK: - Extraction

extension XProfileScraper {

    /// JavaScript that extracts tweets from the rendered X profile page.
    /// Excludes retweets by checking for the "reposted" indicator.
    static let extractionScript = """
    (function() {
        var tweets = [];
        var articles = document.querySelectorAll('article[data-testid="tweet"]');

        for (var i = 0; i < articles.length; i++) {
            var article = articles[i];

            // Skip retweets: look for "reposted" social context
            var socialContext = article.querySelector('[data-testid="socialContext"]');
            if (socialContext && socialContext.textContent.toLowerCase().includes('repost')) {
                continue;
            }

            // Get tweet text
            var tweetTextEl = article.querySelector('[data-testid="tweetText"]');
            var tweetText = tweetTextEl ? tweetTextEl.innerText : '';

            // Get author info
            var userNameEl = article.querySelector('[data-testid="User-Name"]');
            var displayName = '';
            var handle = '';
            if (userNameEl) {
                var spans = userNameEl.querySelectorAll('span');
                for (var j = 0; j < spans.length; j++) {
                    var text = spans[j].textContent.trim();
                    if (text.startsWith('@')) {
                        handle = text;
                        break;
                    }
                }
                var nameLinks = userNameEl.querySelectorAll('a');
                if (nameLinks.length > 0) {
                    displayName = nameLinks[0].textContent.trim();
                }
            }

            // Get tweet URL from the time element's parent link
            var timeEl = article.querySelector('time');
            var tweetURL = '';
            var dateStr = '';
            if (timeEl) {
                dateStr = timeEl.getAttribute('datetime') || '';
                var linkEl = timeEl.closest('a');
                if (linkEl) {
                    tweetURL = linkEl.href;
                }
            }

            // Get first image if present
            var imageURL = '';
            var imgEl = article.querySelector('[data-testid="tweetPhoto"] img');
            if (imgEl) {
                imageURL = imgEl.src;
            }

            if (tweetText || tweetURL) {
                tweets.push({
                    text: tweetText,
                    author: displayName,
                    handle: handle,
                    url: tweetURL,
                    imageURL: imageURL,
                    date: dateStr
                });
            }
        }

        return JSON.stringify(tweets);
    })()
    """

    func extractCurrentTweets(from webView: WKWebView) async -> [ParsedTweet] {
        guard let jsonString = try? await webView.evaluateJavaScript(Self.extractionScript) as? String,
              let data = jsonString.data(using: .utf8),
              let rawTweets = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        let dateFormatter = ISO8601DateFormatter()
        var tweets: [ParsedTweet] = []

        for raw in rawTweets {
            let text = raw["text"] as? String ?? ""
            let author = raw["author"] as? String ?? ""
            let handle = raw["handle"] as? String ?? ""
            let url = raw["url"] as? String ?? ""
            let imageURL = raw["imageURL"] as? String
            let dateStr = raw["date"] as? String ?? ""

            guard !url.isEmpty else { continue }

            var publishedDate: Date?
            if !dateStr.isEmpty {
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                publishedDate = dateFormatter.date(from: dateStr)
                if publishedDate == nil {
                    dateFormatter.formatOptions = [.withInternetDateTime]
                    publishedDate = dateFormatter.date(from: dateStr)
                }
            }

            let cleanHandle = handle.hasPrefix("@") ? String(handle.dropFirst()) : handle
            let tweetID = url.split(separator: "/").last.map(String.init) ?? UUID().uuidString

            tweets.append(ParsedTweet(
                id: tweetID,
                text: text,
                author: author,
                authorHandle: cleanHandle,
                url: url,
                imageURL: imageURL?.isEmpty == true ? nil : imageURL,
                publishedDate: publishedDate
            ))
        }

        return tweets
    }

    /// JavaScript to extract the profile avatar image URL from the page header.
    static let profileImageScript = """
    (function() {
        function upgradeSize(url) {
            return url.replace(/_normal\\./, '_400x400.')
                      .replace(/_bigger\\./, '_400x400.')
                      .replace(/_200x200\\./, '_400x400.')
                      .replace(/_mini\\./, '_400x400.');
        }

        // Primary: data-testid="UserAvatar" (link or container) with an img
        var avatar = document.querySelector('[data-testid="UserAvatar"] img');
        if (avatar && avatar.src && avatar.src.includes('profile_images')) {
            return upgradeSize(avatar.src);
        }

        // Fallback 1: any link to the /photo path containing a profile image
        var photoLink = document.querySelector('a[href$="/photo"] img[src*="profile_images"]');
        if (photoLink && photoLink.src) {
            return upgradeSize(photoLink.src);
        }

        // Fallback 2: any img with profile_images in src within the header area
        var headerImgs = document.querySelectorAll('img[src*="profile_images"]');
        if (headerImgs.length > 0) {
            return upgradeSize(headerImgs[0].src);
        }

        return '';
    })()
    """

    /// JavaScript to extract the display name from the profile header.
    static let displayNameScript = """
    (function() {
        // The profile header contains a data-testid="UserName" element
        var userNameEl = document.querySelector('[data-testid="UserName"]');
        if (userNameEl) {
            // The first child span group contains the display name
            var nameSpans = userNameEl.querySelectorAll('span');
            for (var i = 0; i < nameSpans.length; i++) {
                var text = nameSpans[i].textContent.trim();
                if (text && !text.startsWith('@') && text.length > 0) {
                    return text;
                }
            }
        }
        return '';
    })()
    """

    func extractDisplayName(from webView: WKWebView) async -> String? {
        guard let result = try? await webView.evaluateJavaScript(Self.displayNameScript) as? String,
              !result.isEmpty else {
            return nil
        }
        return result
    }

    func extractProfileImageURL(from webView: WKWebView) async -> String? {
        guard let result = try? await webView.evaluateJavaScript(Self.profileImageScript) as? String,
              !result.isEmpty else {
            return nil
        }
        return result
    }
}
