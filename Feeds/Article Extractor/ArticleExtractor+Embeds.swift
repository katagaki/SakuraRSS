import Foundation
import SwiftSoup

extension ArticleExtractor {

    /// Converts supported social embeds into marker paragraphs.
    /// Must run before `removeNoise` so embed elements aren't stripped.
    static func promoteInlineEmbeds(in doc: Document, baseURL: URL? = nil) {
        promoteYouTubeEmbeds(in: doc)
        promoteXEmbeds(in: doc)
        promoteGenericEmbeds(in: doc)
    }

    // MARK: - YouTube

    private static func promoteYouTubeEmbeds(in element: Element) {
        if let iframes = try? element.select("iframe[src]") {
            for iframe in iframes {
                guard let src = try? iframe.attr("src"),
                      let videoID = youTubeVideoID(fromEmbedURL: src) else {
                    continue
                }
                replaceWithMarker(element: iframe,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        if let liteElements = try? element.select("lite-youtube[videoid]") {
            for lite in liteElements {
                guard let videoID = try? lite.attr("videoid"),
                      !videoID.isEmpty else { continue }
                replaceWithMarker(element: lite,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        if let ytShells = try? element.select(
            "div[data-youtube-id], div[data-youtube-video-id]"
        ) {
            for shell in ytShells {
                // SwiftSoup's `attr` returns "" for missing attributes, so
                // nil-coalescing cannot select the first non-empty value.
                var videoID = (try? shell.attr("data-youtube-id")) ?? ""
                if videoID.isEmpty {
                    videoID = (try? shell.attr("data-youtube-video-id")) ?? ""
                }
                guard !videoID.isEmpty else { continue }
                replaceWithMarker(element: shell,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }

        if let anchors = try? element.select("p > a[href], figure > a[href]") {
            for anchor in anchors {
                guard let parent = anchor.parent() else { continue }
                let siblingCount = parent.children().size()
                guard siblingCount == 1 else { continue }
                guard let href = try? anchor.attr("href"),
                      let videoID = youTubeVideoID(fromWatchURL: href) else {
                    continue
                }
                let text = (try? anchor.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Only collapse when link text is the URL itself; otherwise
                // the anchor text is meaningful and should remain.
                guard trimmed == href || trimmed.isEmpty else { continue }
                replaceWithMarker(element: parent,
                                  marker: "{{YOUTUBE}}\(videoID){{/YOUTUBE}}")
            }
        }
    }

    /// Extracts a YouTube video ID from a `/embed/VIDEO_ID` style URL.
    static func youTubeVideoID(fromEmbedURL src: String) -> String? {
        let lowered = src.lowercased()
        let isYT = lowered.contains("youtube.com/embed/")
            || lowered.contains("youtube-nocookie.com/embed/")
            || lowered.contains("youtube.com/shorts/")
        guard isYT, let url = URL(string: absoluteURLString(src)) else { return nil }
        let parts = url.path.split(separator: "/")
        guard let last = parts.last else { return nil }
        let id = String(last).trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? nil : id
    }

    /// Extracts a YouTube video ID from a watch, shorts, or youtu.be URL.
    static func youTubeVideoID(fromWatchURL src: String) -> String? {
        guard let url = URL(string: absoluteURLString(src)),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let host = components.host?.lowercased() ?? ""
        if host.contains("youtube.com") {
            if components.path.hasPrefix("/shorts/") || components.path.hasPrefix("/embed/") {
                let parts = components.path.split(separator: "/")
                if parts.count >= 2 { return String(parts[1]) }
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }
        if host.contains("youtu.be") {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }
        return nil
    }

    // MARK: - X / Twitter

    private static func promoteXEmbeds(in element: Element) {
        if let blockquotes = try? element.select("blockquote.twitter-tweet") {
            for blockquote in blockquotes {
                guard let anchor = xStatusAnchor(in: blockquote),
                      let href = try? anchor.attr("href"),
                      let normalized = normalizedXStatusURL(href) else {
                    continue
                }
                replaceWithMarker(element: blockquote,
                                  marker: "{{XPOST}}\(normalized){{/XPOST}}")
            }
        }

        if let iframes = try? element.select("iframe[src]") {
            for iframe in iframes {
                guard let src = try? iframe.attr("src"),
                      let url = URL(string: absoluteURLString(src)),
                      let host = url.host?.lowercased(),
                      host.contains("platform.twitter.com")
                        || host.contains("platform.x.com")
                        || host.contains("publish.twitter.com")
                        || host.contains("publish.x.com") else {
                    continue
                }
                if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "id" })?.value,
                   !id.isEmpty,
                   let normalized = normalizedXStatusURL("https://x.com/i/status/\(id)") {
                    replaceWithMarker(element: iframe,
                                      marker: "{{XPOST}}\(normalized){{/XPOST}}")
                }
            }
        }

        if let anchors = try? element.select("p > a[href], figure > a[href]") {
            for anchor in anchors {
                guard let parent = anchor.parent() else { continue }
                let siblingCount = parent.children().size()
                guard siblingCount == 1 else { continue }
                guard let href = try? anchor.attr("href"),
                      let normalized = normalizedXStatusURL(href) else {
                    continue
                }
                let text = (try? anchor.text()) ?? ""
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed == href || trimmed.isEmpty else { continue }
                replaceWithMarker(element: parent,
                                  marker: "{{XPOST}}\(normalized){{/XPOST}}")
            }
        }
    }

    private static func xStatusAnchor(in blockquote: Element) -> Element? {
        guard let anchors = try? blockquote.select("a[href]") else { return nil }
        for anchor in anchors {
            let href = (try? anchor.attr("href")) ?? ""
            if normalizedXStatusURL(href) != nil { return anchor }
        }
        return nil
    }

    /// Returns a canonicalized x.com status URL, or nil if unrecognizable.
    static func normalizedXStatusURL(_ src: String) -> String? {
        guard let url = URL(string: absoluteURLString(src)),
              let host = url.host?.lowercased() else {
            return nil
        }
        let isXHost = host == "x.com" || host.hasSuffix(".x.com")
            || host == "twitter.com" || host.hasSuffix(".twitter.com")
            || host == "mobile.twitter.com" || host == "mobile.x.com"
        guard isXHost else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let statusIndex = parts.firstIndex(of: "status"),
              statusIndex + 1 < parts.count else {
            return nil
        }
        let id = parts[statusIndex + 1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "?#"))
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else { return nil }
        let user: String
        if statusIndex > 0 {
            let candidate = parts[statusIndex - 1]
            user = (candidate == "i" || candidate == "web") ? "i" : candidate
        } else {
            user = "i"
        }
        return "https://x.com/\(user)/status/\(id)"
    }

    // MARK: - Marker detection

    /// Returns the marker if `text` is exactly a single embed marker.
    static func embedMarkerParagraph(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let patterns = [
            #"^\{\{YOUTUBE\}\}[A-Za-z0-9_\-]+\{\{/YOUTUBE\}\}$"#,
            #"^\{\{XPOST\}\}https?://[^\s]+\{\{/XPOST\}\}$"#,
            #"^\{\{EMBED\}\}[a-z]+\|[^\s]+\{\{/EMBED\}\}$"#
        ]
        for pattern in patterns where trimmed.range(
            of: pattern, options: .regularExpression
        ) != nil {
            return trimmed
        }
        return nil
    }

    // MARK: - Helpers

    /// Resolves protocol-relative URLs to `https:` so downstream parsing sees an absolute host.
    private static func absoluteURLString(_ src: String) -> String {
        if src.hasPrefix("//") { return "https:\(src)" }
        return src
    }

    /// Replaces a DOM element with a `<p>` containing only the marker string.
    /// Hoists through single-child wrapper elements so the marker surfaces at article level.
    private static func replaceWithMarker(element: Element, marker: String) {
        let target = outermostEmbedWrapper(for: element)
        do {
            try target.before("<p>\(marker)</p>")
            try target.remove()
        } catch {
        }
    }

    /// Walks up through single-child wrapper elements around an embed.
    private static func outermostEmbedWrapper(for element: Element) -> Element {
        let wrapperTags: Set<String> = ["figure", "div", "aside", "p", "span"]
        var current: Element = element
        while let parent = current.parent(), wrapperTags.contains(parent.tagName().lowercased()) {
            let siblings = parent.children().filter { $0 !== current }
            let siblingHasText = siblings.contains { element in
                let text = ((try? element.text()) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !text.isEmpty
            }
            if siblingHasText { break }
            let ownText = parent.ownText()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !ownText.isEmpty { break }
            current = parent
        }
        return current
    }
}
