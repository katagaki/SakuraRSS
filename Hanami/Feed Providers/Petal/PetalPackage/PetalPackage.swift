import Foundation
import UniformTypeIdentifiers

/// Import/export helpers for `.srss` (Sakura Web Feed) packages.
public nonisolated enum PetalPackage {

    public static let fileExtension = "srss"
    public static let mimeType = "application/x-sakura-rss"

    public static let contentType: UTType = {
        if let registered = UTType("com.tsubuzaki.SakuraRSS.petal") {
            return registered
        }
        if let fromExtension = UTType(filenameExtension: fileExtension,
                                      conformingTo: .zip) {
            return fromExtension
        }
        return .zip
    }()

    public static let formatVersion = 1

    public enum PackageError: LocalizedError {
        case missingRecipe
        case unsupportedVersion
        case malformed
        case tooLarge

        public var errorDescription: String? {
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

    public struct ImportedPackage: Sendable {
        public var recipe: PetalRecipe
        public var iconData: Data?
        public var metadata: Metadata
    }

    public struct Metadata: Codable, Sendable {
        public var formatVersion: Int
        public var exportedAt: Date
        public var appVersion: String?
        public var appBuild: String?
    }

    // MARK: - Shared helpers

    public static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Strips filesystem-hostile characters from a feed name. Callers must
    /// still sandbox the resulting write destination to prevent path escapes.
    public static func sanitizedFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = raw
            .components(separatedBy: invalid)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
        return sanitized.isEmpty ? "WebFeed" : sanitized
    }
}
