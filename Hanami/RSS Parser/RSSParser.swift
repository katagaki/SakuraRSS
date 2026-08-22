import Foundation

public nonisolated final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    var currentTitle = ""
    var currentLink = ""
    var currentDescription = ""
    var currentAuthor = ""
    var currentContent = ""
    var currentDateStrings: [String: String] = [:]
    var currentImageURL = ""
    var currentAudioURL = ""
    var currentDuration = ""

    var feedTitle = ""
    var feedLink = ""
    var feedDescription = ""
    var feedGenerator = ""

    var parsedArticles: [ParsedArticle] = []
    var isInsideItem = false
    var isInsideImage = false
    var isAtom = false
    var hasITunesNamespace = false
    var elementDepth = 0
    var captureStack: [RSSParserCaptureFrame] = []

    public func parse(data: Data) -> ParsedFeed? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        resetState()
        guard parser.parse() else { return nil }
        let trimmedGenerator = feedGenerator.trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedFeed(
            title: RSSParser.decodeHTMLEntities(feedTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
            siteURL: feedLink.trimmingCharacters(in: .whitespacesAndNewlines),
            description: cleanHTMLPreservingStructure(
                feedDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: URL(string: feedLink.trimmingCharacters(in: .whitespacesAndNewlines))
            ) ?? "",
            articles: parsedArticles,
            hasITunesNamespace: hasITunesNamespace,
            generator: trimmedGenerator.isEmpty ? nil : trimmedGenerator
        )
    }

    private func resetState() {
        resetItemState()
        feedTitle = ""
        feedLink = ""
        feedDescription = ""
        feedGenerator = ""
        parsedArticles = []
        isInsideItem = false
        isInsideImage = false
        isAtom = false
        hasITunesNamespace = false
        elementDepth = 0
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _: XMLParser,
        didStartElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementDepth += 1
        handleStartElement(elementName, attributes: attributeDict)
        if let frame = captureStack.last, frame.isXHTML {
            appendCharacters(
                RSSParser.openingTagMarkup(elementName, attributes: attributeDict),
                for: frame.elementName
            )
        } else if RSSParser.isCaptureBoundary(elementName) {
            captureStack.append(RSSParserCaptureFrame(
                elementName: elementName,
                depth: elementDepth,
                isXHTML: RSSParser.isXHTMLContainer(elementName, attributes: attributeDict)
            ))
        }
    }

    public func parser(_: XMLParser, foundCharacters string: String) {
        guard let frame = captureStack.last else { return }
        let text = frame.isXHTML ? RSSParser.escapeXMLText(string) : string
        appendCharacters(text, for: frame.elementName)
    }

    public func parser(
        _: XMLParser,
        didEndElement elementName: String,
        namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        if let frame = captureStack.last {
            if frame.depth == elementDepth, frame.elementName == elementName {
                captureStack.removeLast()
            } else if frame.isXHTML {
                appendCharacters("</\(elementName)>", for: frame.elementName)
            }
        }
        elementDepth -= 1

        if elementName == "image" {
            isInsideImage = false
        } else if elementName == "item" || elementName == "entry" {
            finishCurrentItem()
            isInsideItem = false
        }
    }

    private func finishCurrentItem() {
        let trimmedAuthor = currentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAudioURL = currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let articleURL = trimmedLink.isEmpty ? trimmedAudioURL : trimmedLink
        guard !articleURL.isEmpty else { return }

        let title = RSSParser.decodeHTMLEntities(currentTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        let resolvedTitle = title.isEmpty
            ? (cleanHTML(currentDescription).map { String($0.prefix(100)) } ?? "")
            : title
        guard !resolvedTitle.isEmpty else { return }

        parsedArticles.append(ParsedArticle(
            title: resolvedTitle,
            url: articleURL,
            author: trimmedAuthor.isEmpty ? nil : RSSParser.decodeHTMLEntities(trimmedAuthor),
            summary: cleanHTMLPreservingStructure(
                currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: URL(string: articleURL)
            ),
            content: trimmedContent.isEmpty ? nil : trimmedContent,
            imageURL: resolveImageURL(),
            publishedDate: parseDate(preferredItemDateString()),
            audioURL: trimmedAudioURL.isEmpty ? nil : trimmedAudioURL,
            duration: parseDuration(currentDuration.trimmingCharacters(in: .whitespacesAndNewlines))
        ))
    }
}
