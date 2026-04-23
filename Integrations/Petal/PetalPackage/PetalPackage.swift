import Foundation
import UniformTypeIdentifiers

/// Import/export helpers for `.srss` (Sakura Web Feed) packages.
nonisolated enum PetalPackage {

    static let fileExtension = "srss"
    static let mimeType = "application/x-sakura-rss"

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

    /// Strips filesystem-hostile characters from a feed name. Callers must
    /// still sandbox the resulting write destination to prevent path escapes.
    static func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = raw
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "WebFeed" : sanitized
    }
}
