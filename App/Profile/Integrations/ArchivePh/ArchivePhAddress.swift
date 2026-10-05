import Foundation

/// Pages read through archive.today, shared by the iOS and Mac viewers.
enum ArchivePhAddress {

    static func url(for articleURL: URL) -> URL? {
        URL(string: "https://archive.md/\(articleURL.absoluteString)")
    }
}
