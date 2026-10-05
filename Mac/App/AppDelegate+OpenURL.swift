import AppKit
import Hanami

/// The links and files the Catalyst app opened, so they keep working for
/// people updating from it.
extension AppDelegate {

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                importWebFeed(at: url)
            } else if url.scheme == "sakura" {
                openDeepLink(url)
            } else {
                frontWindowController().presentAddFeedSheet(for: url.resolvingFeedScheme)
            }
        }
    }

    private func openDeepLink(_ url: URL) {
        switch url.host {
        case "article":
            if let articleID = url.pathComponents.last.flatMap(Int64.init) {
                openContent(articleID)
            }
        case "open":
            if let request = OpenArticleRequest(url: url) {
                frontWindowController().navigate(
                    to: .webPage(url: request.url, mode: request.mode, textMode: request.textMode)
                )
            }
        case "addfeed":
            if let feedURL = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value {
                frontWindowController().presentAddFeedSheet(for: feedURL)
            }
        default:
            break
        }
    }

    private func importWebFeed(at url: URL) {
        do {
            let package = try PetalPackage.importPackage(from: url)
            _ = try registry.feedManager.addPetalFeed(recipe: package.recipe, iconData: package.iconData)
        } catch {
            let alert = NSAlert()
            alert.messageText = String(localized: "Error.Title", table: "Petal")
            alert.informativeText = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "Error.ImportFailed", table: "Petal")
            alert.runModal()
        }
    }
}
