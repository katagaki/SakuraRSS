import Foundation
import Hanami

extension SakuraRSSApp {

    func handleOpenURL(_ url: URL) {
        guard url.scheme == "sakura" else {
            pendingFeedURL = convertFeedURL(url)
            return
        }
        handleSakuraScheme(url)
    }

    private func handleSakuraScheme(_ url: URL) {
        guard let host = url.host else { return }
        if handleNavigationHost(host, url: url) { return }
        if handleForceFlagHost(host) { return }
        handleAdminHost(host)
    }

    private func handleNavigationHost(_ host: String, url: URL) -> Bool {
        switch host {
        case "article":
            if let idString = url.pathComponents.last,
               let articleID = Int64(idString) {
                pendingArticleID = articleID
            }
        case "open":
            if let request = OpenArticleRequest(url: url) {
                pendingOpenRequest = request
            }
        default:
            return false
        }
        return true
    }

    private func handleForceFlagHost(_ host: String) -> Bool {
        switch host {
        case "delorean":
            DeloreanClock.shared.toggle()
        case "justwokeup":
            forceWhileYouSlept = true
        case "justhadlunch":
            forceAfternoonBrief = true
        case "justgothome":
            forceTodaysSummary = true
        case "reonboard":
            UserDefaults.standard.set(false, forKey: "Onboarding.Completed")
        default:
            return false
        }
        return true
    }

    private func handleAdminHost(_ host: String) {
        switch host {
        case "fixup":
            DatabaseManager.shared.fixup()
            UserDefaults.standard.removeObject(forKey: "App.DatabaseVersion")
        case "arisishere":
            Task { await feedManager.deleteAllArticlesAndRefresh() }
        case "bigbang":
            feedManager.markAllUnread()
        case "howmanybulbs":
            Task {
                SpotlightIndexer.removeAllArticles()
                feedManager.reindexAllArticlesInSpotlight()
            }
        case "putonpipboy":
            handlePutOnPipBoy()
        case "forgetit":
            handleForgetIt()
        default:
            break
        }
    }

    private func handlePutOnPipBoy() {
        wipeAllCachesAndData()
        Task {
            // X/Instagram cookies in Keychain survive the wipe; X must re-extract GraphQL IDs.
            if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                await XProvider.fetchQueryIDsIfNeeded()
            }
            let entries = feedManager.feeds.map { ($0.domain, $0.siteURL as String?) }
            await Iconography.shared.refreshIcons(for: entries)
        }
    }

    private func handleForgetIt() {
        let defaults = UserDefaults.standard
        let staticKeys = [
            "App.SelectedTab",
            "Home.FeedID",
            "Home.ArticleID",
            "FeedsList.FeedID",
            "FeedsList.ArticleID",
            "Display.DefaultStyle",
            "Search.DisplayStyle",
            "Display.DefaultBookmarksStyle",
            "ForceWhileYouSlept",
            "ForceAfternoonBrief",
            "ForceTodaysSummary"
        ]
        for key in staticKeys {
            defaults.removeObject(forKey: key)
        }
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("Display.Style.")
              || key.hasPrefix("openMode-")
              || key.hasPrefix("Labs.") {
            defaults.removeObject(forKey: key)
        }
    }

    /// Wipes app sandbox directories and tmp, preserving the feeds database in the group container.
    func wipeAllCachesAndData() {
        let fileManager = FileManager.default

        let directories: [FileManager.SearchPathDirectory] = [
            .cachesDirectory,
            .applicationSupportDirectory,
            .documentDirectory
        ]
        for searchPath in directories {
            guard let dir = fileManager.urls(
                for: searchPath,
                in: .userDomainMask
            ).first else { continue }
            wipeContents(of: dir)
        }

        wipeContents(of: fileManager.temporaryDirectory)

        if let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) {
            let dbFile = groupURL.appendingPathComponent("Sakura.feeds").lastPathComponent
            let dbWal = groupURL.appendingPathComponent("Sakura.feeds-wal").lastPathComponent
            let dbShm = groupURL.appendingPathComponent("Sakura.feeds-shm").lastPathComponent
            let preserved: Set<String> = [dbFile, dbWal, dbShm]
            wipeContents(of: groupURL, except: preserved)
        }
    }

    func wipeContents(of directory: URL, except: Set<String> = []) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries {
            if except.contains(entry.lastPathComponent) { continue }
            try? fileManager.removeItem(at: entry)
        }
    }

    func convertFeedURL(_ url: URL) -> String {
        let urlString = url.absoluteString
        if urlString.hasPrefix("feed:https://") || urlString.hasPrefix("feed:http://") {
            return String(urlString.dropFirst("feed:".count))
        } else if urlString.hasPrefix("feeds:https://") || urlString.hasPrefix("feeds:http://") {
            return String(urlString.dropFirst("feeds:".count))
        } else if urlString.hasPrefix("feed://") {
            return "https://" + urlString.dropFirst("feed://".count)
        } else if urlString.hasPrefix("feeds://") {
            return "https://" + urlString.dropFirst("feeds://".count)
        }
        return urlString
    }
}
