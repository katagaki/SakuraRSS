import Foundation

nonisolated final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentAuthor = ""
    private var currentContent = ""
    private var currentPubDate = ""
    private var currentImageURL = ""
    private var currentAudioURL = ""
    private var currentDuration = ""

    private var feedTitle = ""
    private var feedLink = ""
    private var feedDescription = ""

    private var parsedArticles: [ParsedArticle] = []
    private var isInsideItem = false
    private var isInsideImage = false
    private var isAtom = false
    private var hasITunesNamespace = false
    private var currentAttributes: [String: String] = [:]

    func parse(data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        resetState()
        guard parser.parse() else { return nil }
        return ParsedFeed(
            title: decodeHTMLEntities(feedTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
            siteURL: feedLink.trimmingCharacters(in: .whitespacesAndNewlines),
            description: cleanHTMLPreservingStructure(feedDescription.trimmingCharacters(in: .whitespacesAndNewlines)) ?? "",
            articles: parsedArticles,
            hasITunesNamespace: hasITunesNamespace
        )
    }

    private func resetState() {
        currentElement = ""
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentAuthor = ""
        currentContent = ""
        currentPubDate = ""
        currentImageURL = ""
        currentAudioURL = ""
        currentDuration = ""
        feedTitle = ""
        feedLink = ""
        feedDescription = ""
        parsedArticles = []
        isInsideItem = false
        isInsideImage = false
        isAtom = false
        hasITunesNamespace = false
    }

    // MARK: - XMLParserDelegate

    // swiftlint:disable cyclomatic_complexity
    func parser(_: XMLParser, didStartElement elementName: String,
                namespaceURI _: String?, qualifiedName _: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentAttributes = attributeDict

        switch elementName {
        case "rss":
            break
        case "feed":
            isAtom = true
        case "image":
            if !isInsideItem { isInsideImage = true }
        case "item", "entry":
            isInsideItem = true
            resetItemState()
        case "link" where isAtom:
            handleAtomLink(attributeDict)
        case "enclosure", "media:content":
            handleMediaElement(elementName, attributes: attributeDict)
        case "media:thumbnail":
            if let url = attributeDict["url"] {
                currentImageURL = url
            }
        case "itunes:type", "itunes:author", "itunes:owner" where !isInsideItem:
            hasITunesNamespace = true
        case "itunes:image" where isInsideItem:
            if let url = attributeDict["href"], currentImageURL.isEmpty {
                currentImageURL = url
            }
        default:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func resetItemState() {
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentAuthor = ""
        currentContent = ""
        currentPubDate = ""
        currentImageURL = ""
        currentAudioURL = ""
        currentDuration = ""
    }

    private func handleAtomLink(_ attributes: [String: String]) {
        let rel = attributes["rel"] ?? "alternate"
        guard let href = attributes["href"], rel == "alternate" else { return }
        if isInsideItem {
            currentLink = href
        } else {
            feedLink = href
        }
    }

    private func handleMediaElement(_ elementName: String, attributes: [String: String]) {
        guard let url = attributes["url"], !url.isEmpty else { return }

        if let type = attributes["type"] {
            if type.hasPrefix("audio/") {
                currentAudioURL = url
                return
            }
            if type.hasPrefix("image/") {
                currentImageURL = url
                return
            }
        }

        if attributes["medium"] == "image" {
            currentImageURL = url
        } else if elementName == "media:content", currentImageURL.isEmpty {
            currentImageURL = url
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        if isInsideItem {
            appendItemCharacters(string)
        } else {
            appendFeedCharacters(string)
        }
    }

    private func appendItemCharacters(_ string: String) {
        switch currentElement {
        case "title": currentTitle += string
        case "link": if !isAtom { currentLink += string }
        case "description", "summary", "subtitle", "media:description": currentDescription += string
        case "dc:creator", "author", "name": currentAuthor += string
        case "content:encoded", "content": currentContent += string
        case "pubDate", "published", "updated", "dc:date": currentPubDate += string
        case "itunes:duration": currentDuration += string
        default: break
        }
    }

    private func appendFeedCharacters(_ string: String) {
        guard !isInsideImage else { return }
        switch currentElement {
        case "title": feedTitle += string
        case "link": if !isAtom { feedLink += string }
        case "description", "subtitle": feedDescription += string
        default: break
        }
    }

    func parser(_: XMLParser, didEndElement elementName: String,
                namespaceURI _: String?, qualifiedName _: String?) {
        if elementName == "image" {
            isInsideImage = false
        } else if elementName == "item" || elementName == "entry" {
            let trimmedAuthor = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedContent = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAudioURL = currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let articleURL = trimmedLink.isEmpty ? trimmedAudioURL : trimmedLink
            let article = ParsedArticle(
                title: decodeHTMLEntities(currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
                url: articleURL,
                author: trimmedAuthor.isEmpty ? nil : decodeHTMLEntities(trimmedAuthor),
                summary: cleanHTMLPreservingStructure(
                    currentDescription.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                ),
                content: trimmedContent.isEmpty ? nil : trimmedContent,
                imageURL: resolveImageURL(),
                publishedDate: parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)),
                audioURL: trimmedAudioURL.isEmpty ? nil : trimmedAudioURL,
                duration: parseDuration(currentDuration.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            if !article.title.isEmpty && !article.url.isEmpty {
                parsedArticles.append(article)
            }
            isInsideItem = false
        }
        currentElement = ""
    }

    // MARK: - Image Resolution

    private func resolveImageURL() -> String? {
        // Prefer explicitly tagged image from feed elements
        if !currentImageURL.isEmpty {
            return currentImageURL
        }
        // Try extracting from content:encoded (usually has full article HTML)
        if !currentContent.isEmpty, let url = extractImageFromHTML(currentContent) {
            return url
        }
        // Try extracting from description/summary
        if !currentDescription.isEmpty, let url = extractImageFromHTML(currentDescription) {
            return url
        }
        return nil
    }
}
