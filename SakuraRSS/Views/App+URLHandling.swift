import Foundation

extension SakuraRSSApp {

    func handleOpenURL(_ url: URL) {
        if url.scheme == "sakura" {
            switch url.host {
            case "article":
                if let idString = url.pathComponents.last,
                   let articleID = Int64(idString) {
                    pendingArticleID = articleID
                }
            case "justwokeup":
                forceWhileYouSlept = true
                UserDefaults.standard.removeObject(forKey: "WhileYouSlept.DismissedDate")
            case "justgothome":
                forceTodaysSummary = true
                UserDefaults.standard.removeObject(forKey: "TodaysSummary.DismissedDate")
            case "reonboard":
                UserDefaults.standard.set(false, forKey: "Onboarding.Completed")
            case "fixup":
                DatabaseManager.shared.fixup()
                UserDefaults.standard.removeObject(forKey: "App.DatabaseVersion")
            case "arisishere":
                Task {
                    await feedManager.deleteAllArticlesAndRefresh()
                }
            case "bigbang":
                feedManager.markAllUnread()
            case "howmanybulbs":
                Task {
                    SpotlightIndexer.removeAllArticles()
                    feedManager.reindexAllArticlesInSpotlight()
                }
            case "putonpipboy":
                wipeAllCachesAndData()
                Task {
                    // X and Instagram cookies live in Keychain, which
                    // survives the filesystem wipe above - no cookie
                    // re-warming needed.  X still has to re-extract its
                    // in-memory GraphQL query IDs from the JS bundle.
                    if UserDefaults.standard.bool(forKey: "Labs.XProfileFeeds") {
                        await XProfileScraper.fetchQueryIDsIfNeeded()
                    }
                    let entries = feedManager.feeds.map { ($0.domain, $0.siteURL as String?) }
                    await FaviconCache.shared.refreshFavicons(for: entries)
                }
            case "forgetit":
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "App.SelectedTab")
                defaults.removeObject(forKey: "Home.FeedID")
                defaults.removeObject(forKey: "Home.ArticleID")
                defaults.removeObject(forKey: "FeedsList.FeedID")
                defaults.removeObject(forKey: "FeedsList.ArticleID")
                defaults.removeObject(forKey: "Display.DefaultStyle")
                defaults.removeObject(forKey: "Search.DisplayStyle")
                defaults.removeObject(forKey: "Display.DefaultBookmarksStyle")
                defaults.removeObject(forKey: "TodaysSummary.DismissedDate")
                defaults.removeObject(forKey: "WhileYouSlept.DismissedDate")
                defaults.removeObject(forKey: "ForceWhileYouSlept")
                defaults.removeObject(forKey: "ForceTodaysSummary")
                for key in defaults.dictionaryRepresentation().keys {
                    if key.hasPrefix("Display.Style.") || key.hasPrefix("openMode-")
                        || key.hasPrefix("Labs.") {
                        defaults.removeObject(forKey: key)
                    }
                }
            default:
                break
            }
        } else {
            pendingFeedURL = convertFeedURL(url)
        }
    }

    /// Wipes everything in the app's Caches, Application Support, Documents,
    /// and tmp directories except the feeds database in the shared app group
    /// container. Invoked via `sakura://putonpipboy`.
    func wipeAllCachesAndData() {
        let fm = FileManager.default

        // Wipe the main app sandbox directories entirely.
        let directories: [FileManager.SearchPathDirectory] = [
            .cachesDirectory,
            .applicationSupportDirectory,
            .documentDirectory
        ]
        for searchPath in directories {
            guard let dir = fm.urls(for: searchPath, in: .userDomainMask).first else { continue }
            wipeContents(of: dir)
        }

        // Wipe the temporary directory.
        wipeContents(of: fm.temporaryDirectory)

        // Wipe the shared app group container, but preserve the feeds database.
        if let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) {
            let dbFile = groupURL.appendingPathComponent("Sakura.feeds").lastPathComponent
            let dbWal = groupURL.appendingPathComponent("Sakura.feeds-wal").lastPathComponent
            let dbShm = groupURL.appendingPathComponent("Sakura.feeds-shm").lastPathComponent
            let preserved: Set<String> = [dbFile, dbWal, dbShm]
            wipeContents(of: groupURL, except: preserved)
        }
    }

    /// Removes every top-level entry inside `directory`, except names in `except`.
    func wipeContents(of directory: URL, except: Set<String> = []) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for entry in entries {
            if except.contains(entry.lastPathComponent) { continue }
            try? fm.removeItem(at: entry)
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
