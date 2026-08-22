import Foundation

extension WidgetThumbnailCache {

    private static let maxScopeAge: TimeInterval = 14 * 24 * 60 * 60
    private static let maxScopeCount = 12

    static var scopesDirectory: URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tsubuzaki.SakuraRSS"
        ) else { return nil }
        return container.appendingPathComponent("WidgetThumbnails", isDirectory: true)
    }

    /// Scope names embed the feed, list, layout, column count and pixel size, so
    /// reconfigured or removed widgets would otherwise leak directories forever.
    static func pruneStaleScopes() {
        guard let scopesDirectory else { return }
        let fileManager = FileManager.default
        let scopes = (try? fileManager.contentsOfDirectory(
            at: scopesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var survivors: [(url: URL, modifiedAt: Date)] = []
        let cutoff = Date().addingTimeInterval(-maxScopeAge)
        for scope in scopes {
            let values = try? scope.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let modifiedAt = values?.contentModificationDate ?? .distantPast
            if modifiedAt < cutoff {
                try? fileManager.removeItem(at: scope)
            } else {
                survivors.append((scope, modifiedAt))
            }
        }

        guard survivors.count > maxScopeCount else { return }
        let expired = survivors
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .dropFirst(maxScopeCount)
        for scope in expired {
            try? fileManager.removeItem(at: scope.url)
        }
    }

    func touch() {
        guard let directory else { return }
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()], ofItemAtPath: directory.path
        )
    }
}
