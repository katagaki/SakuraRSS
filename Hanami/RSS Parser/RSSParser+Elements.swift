import Foundation

nonisolated extension RSSParser {

    func handleStartElement(_ elementName: String, attributes attributeDict: [String: String]) {
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
        default:
            handleITunesElement(elementName, attributes: attributeDict)
        }
    }

    private func handleITunesElement(_ elementName: String, attributes attributeDict: [String: String]) {
        switch elementName {
        case "itunes:type" where !isInsideItem,
             "itunes:author" where !isInsideItem,
             "itunes:owner" where !isInsideItem:
            hasITunesNamespace = true
        case "itunes:image" where isInsideItem:
            if let url = attributeDict["href"], currentImageURL.isEmpty {
                currentImageURL = url
            }
        default:
            break
        }
    }

    func resetItemState() {
        captureStack.removeAll()
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentAuthor = ""
        currentContent = ""
        currentDateStrings = [:]
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

    func appendCharacters(_ string: String, for elementName: String) {
        if isInsideItem {
            appendItemCharacters(string, for: elementName)
        } else {
            appendFeedCharacters(string, for: elementName)
        }
    }

    private func appendItemCharacters(_ string: String, for elementName: String) {
        switch elementName {
        case "title": currentTitle += string
        case "link": if !isAtom { currentLink += string }
        case "description", "summary", "subtitle", "media:description": currentDescription += string
        case "dc:creator", "author", "name": currentAuthor += string
        case "content:encoded", "content": currentContent += string
        // Kept separate per element; feeds like PubMed provide several date elements per item
        case "pubDate", "published", "dc:date", "updated":
            currentDateStrings[elementName, default: ""] += string
        case "itunes:duration": currentDuration += string
        default: break
        }
    }

    private func appendFeedCharacters(_ string: String, for elementName: String) {
        guard !isInsideImage else { return }
        switch elementName {
        case "title": feedTitle += string
        case "link": if !isAtom { feedLink += string }
        case "description", "subtitle": feedDescription += string
        case "generator": feedGenerator += string
        default: break
        }
    }

    func preferredItemDateString() -> String {
        let elementPriority = ["pubDate", "published", "dc:date", "updated"]
        for elementName in elementPriority {
            guard let value = currentDateStrings[elementName] else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    func resolveImageURL() -> String? {
        if !currentImageURL.isEmpty {
            return currentImageURL
        }
        if !currentContent.isEmpty, let url = extractImageFromHTML(currentContent) {
            return url
        }
        if !currentDescription.isEmpty, let url = extractImageFromHTML(currentDescription) {
            return url
        }
        return nil
    }
}
