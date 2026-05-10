import Foundation

public struct NextPageURLCollector {
    public let baseURL: URL
    public private(set) var urls: [URL] = []
    private var seen: Set<String> = []

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public mutating func add(_ href: String) {
        guard let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL else { return }
        let absolute = resolved.absoluteString
        if seen.contains(absolute) { return }
        seen.insert(absolute)
        urls.append(resolved)
    }
}
