import Foundation

nonisolated extension PetalPackage {

    // MARK: - Export

    /// Serializes a recipe plus optional icon into a `.srss` ZIP archive.
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

    /// Exports to a temp file and returns the URL for `ShareLink` / `fileExporter`.
    /// Writes into a fresh UUID-named subdirectory to sandbox the user-controlled name.
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
        // Defense in depth: reject any path that escapes the sandbox after normalization.
        let resolvedPath = tempURL.standardizedFileURL.path
        let sandboxPath = sandbox.standardizedFileURL.path
        guard resolvedPath.hasPrefix(sandboxPath + "/") else {
            throw PackageError.malformed
        }

        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
}
