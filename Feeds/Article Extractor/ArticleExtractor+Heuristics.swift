import Foundation

extension ArticleExtractor {

    /// True when the HTML looks like a JS-rendered shell (retry via WebView).
    static func looksJSRendered(_ html: String) -> Bool {
        let skeletonMarkers = [
            #"<div id="__next">\s*</div>"#,
            #"<div id="__nuxt">\s*</div>"#,
            #"<div id="root">\s*</div>"#,
            #"<div id="app">\s*</div>"#,
            #"<div id="app-root">\s*</div>"#,
            #"<noscript>[^<]*(?:enable|turn on)[^<]*JavaScript"#
        ]
        for marker in skeletonMarkers {
            // swiftlint:disable:next for_where
            if html.range(
                of: marker,
                options: [.regularExpression, .caseInsensitive]
            ) != nil {
                return true
            }
        }

        let bodyStart = html.range(of: "<body", options: .caseInsensitive)
        let bodyEnd = html.range(of: "</body>", options: .caseInsensitive)
        if let bodyStart, let bodyEnd,
           bodyStart.upperBound < bodyEnd.lowerBound {
            let bodyRange = bodyStart.upperBound..<bodyEnd.lowerBound
            let bodyHTML = String(html[bodyRange])
            let bodyText = bodyHTML.replacingOccurrences(
                of: "<[^>]+>", with: "", options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            let scriptCount = bodyHTML
                .components(separatedBy: "<script").count - 1
            if bodyText.count < 500 && scriptCount > 10 {
                return true
            }
        }
        return false
    }

    /// True when extracted text is too short or sparse to trust; triggers WebView fallback.
    static func isWeakExtraction(_ text: String?) -> Bool {
        guard let text, !text.isEmpty else { return true }
        let paragraphCount = text.components(separatedBy: "\n\n").count
        return paragraphCount < 2 || text.count < 400
    }
}
