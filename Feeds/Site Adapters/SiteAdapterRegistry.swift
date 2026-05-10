import Foundation

enum SiteAdapterRegistry {

    static let all: [SiteAdapter] = [
        WikipediaAdapter(),
        GitHubAdapter(),
        StackOverflowAdapter(),
        VergeAdapter(),
        ZennAdapter(),
        MothershipAdapter(),
        TomsHardwareAdapter(),
        France24Adapter(),
        AppleAdapter(),
        ZDNETAdapter()
    ]

    static func adapter(for url: URL) -> SiteAdapter? {
        all.first { $0.canHandle(url: url) }
    }
}
