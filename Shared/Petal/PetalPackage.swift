import Foundation
import UniformTypeIdentifiers

/// Import/export helpers for `.srss` (Sakura RSS) packages.
///
/// A `.srss` file is a small ZIP archive containing:
///
/// ```
/// recipe.json    PetalRecipe JSON
/// icon.png       optional feed icon
/// metadata.json  { "formatVersion": 1, "exportedAt": ..., "appVersion": ... }
/// ```
///
/// The format is intentionally simple so power users can hand-edit
/// their recipes outside the app, and the metadata sidecar gives the
/// importer somewhere to reject future incompatible formats.
nonisolated enum PetalPackage {

    static let fileExtension = "srss"
    static let mimeType = "application/x-sakura-rss"

    /// UTType used by `fileImporter` and `fileExporter` to recognize
    /// `.srss` packages.  The type is declared in Info.plist as an
    /// exported type conforming to `public.zip-archive`; here we
    /// resolve it at runtime and fall back to a dynamic type built
    /// from the file extension so a misconfigured plist can't break
    /// the importer sheet.
    static let contentType: UTType = {
        if let registered = UTType("com.tsubuzaki.SakuraRSS.petal") {
            return registered
        }
        if let fromExtension = UTType(filenameExtension: fileExtension,
                                      conformingTo: .zip) {
            return fromExtension
        }
        return .zip
    }()

    /// Current on-disk package format.  Bump whenever the contents
    /// of `recipe.json` become non-forward-compatible.
    static let formatVersion = 1

    enum PackageError: LocalizedError {
        case missingRecipe
        case unsupportedVersion
        case malformed
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .missingRecipe:
                String(localized: "Petal.Error.PackageMissingRecipe")
            case .unsupportedVersion:
                String(localized: "Petal.Error.PackageUnsupportedVersion")
            case .malformed:
                String(localized: "Petal.Error.PackageMalformed")
            case .tooLarge:
                String(localized: "Petal.Error.PackageTooLarge")
            }
        }
    }

    struct ImportedPackage: Sendable {
        var recipe: PetalRecipe
        var iconData: Data?
        var metadata: Metadata
    }

    struct Metadata: Codable, Sendable {
        var formatVersion: Int
        var exportedAt: Date
        var appVersion: String?
        var appBuild: String?
    }

    // MARK: - Export

    /// Serializes a recipe (plus optional icon) into a `.srss` blob.
    static func export(
        recipe: PetalRecipe,
        iconPNG: Data? = nil
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

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

    /// Convenience: exports straight to a temp file and returns the
    /// URL so callers can hand it to `ShareLink` / `fileExporter`.
    ///
    /// The output goes into a *fresh, UUID-named* subdirectory of
    /// the temp directory rather than the temp directory itself.
    /// Even though `sanitizedFilename` already strips path
    /// separators, writing into a throwaway subdirectory makes the
    /// trust barrier between the user-controlled `recipe.name` and
    /// the real filesystem explicit — a malicious name can only
    /// clobber files inside the one-use subfolder we just created.
    /// The resolved path is re-checked to guarantee it lives under
    /// the sandbox folder before we write anything.
    static func exportToTempFile(
        recipe: PetalRecipe,
        iconPNG: Data? = nil
    ) throws -> URL {
        let data = try export(recipe: recipe, iconPNG: iconPNG)
        let safeName = sanitizedFilename(recipe.name)
        let filename = "\(safeName).\(fileExtension)"

        let sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("PetalExport-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(
            at: sandbox, withIntermediateDirectories: true
        )

        let tempURL = sandbox.appendingPathComponent(filename)
        // Defense in depth: reject any path that escapes the
        // sandbox after normalization.  This can't happen with the
        // current sanitizer, but the guard documents the invariant
        // and keeps Sonar / future refactors honest.
        let resolvedPath = tempURL.standardizedFileURL.path
        let sandboxPath = sandbox.standardizedFileURL.path
        guard resolvedPath.hasPrefix(sandboxPath + "/") else {
            throw PackageError.malformed
        }

        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }

    // MARK: - Import

    /// Parses a `.srss` package.  Use `importPackage(from:)` when you
    /// have a file URL; this overload handles raw bytes for tests and
    /// share-extension pass-through.
    static func importPackage(from data: Data) throws -> ImportedPackage {
        // Reject oversized payloads before even trying to unzip them.
        // Legitimate packages are a few KB; anything past the ZIP
        // reader's total budget is rejected outright so the user
        // sees a friendly error instead of a generic "malformed".
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

        guard let recipeEntry = entries.first(where: { $0.name == "recipe.json" }) else {
            throw PackageError.missingRecipe
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let recipe: PetalRecipe
        do {
            recipe = try decoder.decode(PetalRecipe.self, from: recipeEntry.data)
        } catch {
            throw PackageError.malformed
        }
        guard recipe.version <= PetalRecipe.currentVersion else {
            throw PackageError.unsupportedVersion
        }

        let metadata: Metadata = {
            guard let entry = entries.first(where: { $0.name == "metadata.json" }),
                  let decoded = try? decoder.decode(Metadata.self, from: entry.data) else {
                return Metadata(
                    formatVersion: formatVersion,
                    exportedAt: Date(),
                    appVersion: nil,
                    appBuild: nil
                )
            }
            return decoded
        }()

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

    // MARK: - Helpers

    private static func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = raw
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "Petal" : sanitized
    }
}
