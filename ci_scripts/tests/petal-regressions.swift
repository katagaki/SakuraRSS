import Foundation
import SQLite

public nonisolated enum PetalEngine {}

let connection = try Connection(.inMemory)
let legacyEntries = try PetalBackupArchive.read(from: connection)
assert(legacyEntries.isEmpty)
var recipe = PetalRecipe(name: "Backup test", siteURL: "https://example.com/blog", itemSelector: ".card")
recipe.titleSelector = "[class*=title]"
recipe.fetchMode = .rendered
let originalIcon = Data([0, 1, 2, 255])
try PetalBackupArchive.write([.init(recipe: recipe, iconData: originalIcon)], to: connection)
let restoredEntries = try PetalBackupArchive.read(from: connection)
assert(restoredEntries.count == 1)
assert(restoredEntries[0].recipe.id == recipe.id)
assert(restoredEntries[0].recipe.fetchMode == .rendered)
assert(restoredEntries[0].recipe.titleSelector == "[class*=title]")
assert(restoredEntries[0].iconData == originalIcon)
try PetalBackupArchive.write([], to: connection)
let clearedEntries = try PetalBackupArchive.read(from: connection)
assert(clearedEntries.isEmpty)
try PetalBackupArchive.write([.init(recipe: recipe, iconData: nil)], to: connection)
try connection.run("UPDATE petal_backup_recipes SET recipe_data = X'00'")
do {
    _ = try PetalBackupArchive.read(from: connection)
    fatalError("Corrupt recipes must fail before restore")
} catch {}
print("PASS: legacy backup, recipe/icon round trip, stale rows, corrupt payload")

let recoveredRecipe = PetalRecipe.recoveryRecipe(name: "Restored feed", feedURL: recipe.feedURL)
assert(recoveredRecipe?.siteURL == recipe.siteURL)
assert(recoveredRecipe?.itemSelector == "")
assert(PetalRecipe.recoveryRecipe(name: "RSS", feedURL: "https://example.com/rss") == nil)
print("PASS: missing-recipe recovery")

let navigation = (1...20).map { index in
    "<div class='clickable_wrap'><a href='/nav/\(index)'>Navigation \(index)</a></div>"
}.joined()
let cards = (1...6).map { index in
    """
    <div class='blog_card'><div class='blog_card_title'>Content \(index)</div>
    <div class='clickable_wrap'><a href='/blog/\(index)'>Read more</a></div></div>
    """
}.joined()
let html = "<html><head><title>Test Blog</title></head><body>\(navigation)\(cards)</body></html>"
let detectedRecipe = PetalAutoDetect.detect(html: html, siteURL: recipe.siteURL)!
let parsedItems = PetalEngine.parse(html: html, recipe: detectedRecipe)
assert(parsedItems.count == 6)
assert(parsedItems.allSatisfy { $0.title.hasPrefix("Content ") && $0.url.contains("/blog/") })
print("PASS: content cards preferred over navigation wrappers")

let snapshotDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: snapshotDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: snapshotDirectory) }
let sourceConnection = try Connection(snapshotDirectory.appendingPathComponent("source.sqlite").path)
try sourceConnection.run("PRAGMA journal_mode = WAL")
try sourceConnection.run("CREATE TABLE feeds (title TEXT)")
try sourceConnection.run("INSERT INTO feeds VALUES ('Committed WAL content')")
try PetalBackupArchive.write([.init(recipe: recipe, iconData: originalIcon)], to: sourceConnection)
let snapshotConnection = try Connection(snapshotDirectory.appendingPathComponent("backup.sqlite").path)
let snapshot = try sourceConnection.backup(usingConnection: snapshotConnection)
try snapshot.step()
let snapshotTitle = try snapshotConnection.scalar("SELECT title FROM feeds") as? String
assert(snapshotTitle == "Committed WAL content")
let snapshotRecipes = try PetalBackupArchive.read(from: snapshotConnection)
assert(snapshotRecipes.count == 1 && snapshotRecipes[0].iconData == originalIcon)
print("PASS: SQLite snapshot includes committed WAL data and recipe files")

if CommandLine.arguments.count > 1 {
    let liveHTML = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
    let liveRecipe = PetalAutoDetect.detect(html: liveHTML, siteURL: "https://claude.com/blog")!
    let liveItems = PetalEngine.parse(html: liveHTML, recipe: liveRecipe)
    assert(liveItems.count >= 10)
    assert(liveItems.allSatisfy { $0.url.hasPrefix("https://claude.com/blog/") })
    assert(liveItems.contains { $0.url.contains("claude-code-mods") })
    print("PASS: Claude blog", liveItems.count, "items; selector:", liveRecipe.itemSelector)
}
