import Foundation

nonisolated extension PetalPackage {

    // MARK: - Import

    /// Parses a `.srss` package from raw bytes.  Use the URL
    /// overload when you have a file URL; this one handles raw
    /// `Data` for tests and share-extension pass-through.
    static func importPackage(from data: Data) throws -> ImportedPackage {
        // Reject oversized payloads before even trying to unzip
        // them.  Legitimate packages are a few KB; anything past
        // the ZIP reader's total budget is rejected outright so
        // the user sees a friendly error instead of a generic
        // "malformed".
        guard data.count <= PetalZip.Limits.maxTotalUncompressedSize * 2 else {
            throw PackageError.tooLarge
        }
        let entries: [PetalZip.Entry]
        do {
            entries = try PetalZip.read(data: data)
        } catch PetalZip.ZipError.tooLarge {
            throw PackageError.tooLarge
        } catch {
            throw PackageError.malformed
        }

        let recipe = try decodeRecipe(from: entries)
        let metadata = decodeMetadata(from: entries)
        let iconData = entries.first(where: { $0.name == "icon.png" })?.data

        return ImportedPackage(
            recipe: recipe,
            iconData: iconData,
            metadata: metadata
        )
    }

    static func importPackage(from url: URL) throws -> ImportedPackage {
        let data = try Data(contentsOf: url)
        return try importPackage(from: data)
    }

    // MARK: - Decoding

    private static func decodeRecipe(
        from entries: [PetalZip.Entry]
    ) throws -> PetalRecipe {
        guard let recipeEntry = entries.first(where: { $0.name == "recipe.json" }) else {
            throw PackageError.missingRecipe
        }
        let decoder = makeJSONDecoder()
        let recipe: PetalRecipe
        do {
            recipe = try decoder.decode(PetalRecipe.self, from: recipeEntry.data)
        } catch {
            throw PackageError.malformed
        }
        guard recipe.version <= PetalRecipe.currentVersion else {
            throw PackageError.unsupportedVersion
        }
        return recipe
    }

    /// Decoding the metadata is best-effort: if the sidecar is
    /// missing or unreadable we synthesise one rather than
    /// failing the whole import, because a valid recipe alone is
    /// still a usable package.
    private static func decodeMetadata(
        from entries: [PetalZip.Entry]
    ) -> Metadata {
        guard let entry = entries.first(where: { $0.name == "metadata.json" }),
              let decoded = try? makeJSONDecoder().decode(Metadata.self, from: entry.data) else {
            return Metadata(
                formatVersion: formatVersion,
                exportedAt: Date(),
                appVersion: nil,
                appBuild: nil
            )
        }
        return decoded
    }
}
