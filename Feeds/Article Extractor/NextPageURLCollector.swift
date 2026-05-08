import Foundation

struct NextPageURLCollector {
    let baseURL: URL
    private(set) var urls: [URL] = []
    private var seen: Set<String> = []

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    mutating func add(_ href: String) {
        guard let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL else { return }
        let absolute = resolved.absoluteString
        if seen.contains(absolute) { return }
        seen.insert(absolute)
        urls.append(resolved)
    }
}
