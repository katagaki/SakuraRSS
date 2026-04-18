import Foundation
import UniformTypeIdentifiers

/// Import/export helpers for `.srss` (Sakura Web Feed) packages.
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
/// their recipes outside the app, and the metadata sidecar gives
/// the importer somewhere to reject future incompatible formats.
///
/// Implementation lives across several files in this folder:
///   - `PetalPackage.swift` - this file: type, nested values,
///     UTType plumbing, and shared helpers.
///   - `PetalPackage+Export.swift` - serialization / temp-file
///     export.
///   - `PetalPackage+Import.swift` - parsing / validation.
nonisolated enum PetalPackage {

    static let fileExtension = "srss"
    static let mimeType = "application/x-sakura-rss"

    /// UTType used by `fileImporter` and `fileExporter` to
    /// recognize `.srss` packages.  The type is declared in
    /// `Info.plist` as an exported type conforming to
    /// `public.zip-archive`; here we resolve it at runtime and
    /// fall back to a dynamic type built from the file extension
    /// so a misconfigured plist can't break the importer sheet.
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
                String(localized: "Error.PackageMissingRecipe", table: "Petal")
            case .unsupportedVersion:
                String(localized: "Error.PackageUnsupportedVersion", table: "Petal")
            case .malformed:
                String(localized: "Error.PackageMalformed", table: "Petal")
            case .tooLarge:
                String(localized: "Error.PackageTooLarge", table: "Petal")
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

    // MARK: - Shared helpers

    /// Builds a JSON encoder configured the way both `.srss`
    /// metadata and the recipe use it - pretty-printed with
    /// sorted keys so hand-diffs stay stable, and ISO8601 dates
    /// so the format survives a trip through non-Apple tooling.
    static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Strips filesystem-hostile characters from a feed name so
    /// it can safely become a filename.  Does **not** by itself
    /// prevent path escapes - callers must still sandbox the
    /// resulting write destination.  See `exportToTempFile`.
    static func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = raw
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "WebFeed" : sanitized
    }
}
