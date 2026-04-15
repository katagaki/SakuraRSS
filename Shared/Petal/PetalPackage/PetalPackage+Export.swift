import Foundation

nonisolated extension PetalPackage {

    // MARK: - Export

    /// Serializes a recipe (plus optional icon) into a `.srss`
    /// blob.  Recipes, metadata, and an optional PNG icon are
    /// bundled together as a ZIP archive.
    static func export(
        recipe: PetalRecipe,
        iconPNG: Data? = nil
    ) throws -> Data {
        let encoder = makeJSONEncoder()
        let recipeData = try encoder.encode(recipe)

        let metadata = Metadata(
            formatVersion: formatVersion,
            exportedAt: Date(),
            appVersion: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        let metadataData = try encoder.encode(metadata)

        var entries: [PetalZip.Entry] = [
            .init(name: "recipe.json", data: recipeData),
            .init(name: "metadata.json", data: metadataData)
        ]
        if let iconPNG, !iconPNG.isEmpty {
            entries.append(.init(name: "icon.png", data: iconPNG))
        }
        return PetalZip.write(entries: entries)
    }

    /// Convenience: exports straight to a temp file and returns
    /// the URL so callers can hand it to `ShareLink` /
    /// `fileExporter`.
    ///
    /// The output goes into a *fresh, UUID-named* subdirectory of
    /// the temp directory rather than the temp directory itself.
    /// Even though `sanitizedFilename` already strips path
    /// separators, writing into a throwaway subdirectory makes
    /// the trust barrier between the user-controlled `recipe.name`
    /// and the real filesystem explicit — a malicious name can
    /// only clobber files inside the one-use subfolder we just
    /// created.  The resolved path is re-checked to guarantee it
    /// lives under the sandbox folder before we write anything.
    static func exportToTempFile(
        recipe: PetalRecipe,
        iconPNG: Data? = nil
    ) throws -> URL {
        let data = try export(recipe: recipe, iconPNG: iconPNG)
        let safeName = sanitizedFilename(recipe.name)
        let filename = "\(safeName).\(fileExtension)"

        let sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebFeedExport-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: sandbox, withIntermediateDirectories: true
        )

        let tempURL = sandbox.appendingPathComponent(filename)
        // Defense in depth: reject any path that escapes the
        // sandbox after normalization.  This can't happen with
        // the current sanitizer, but the guard documents the
        // invariant and keeps Sonar / future refactors honest.
        let resolvedPath = tempURL.standardizedFileURL.path
        let sandboxPath = sandbox.standardizedFileURL.path
        guard resolvedPath.hasPrefix(sandboxPath + "/") else {
            throw PackageError.malformed
        }

        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}
