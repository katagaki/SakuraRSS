import Foundation

public enum SiteContentExtractorRegistry {

    public static let all: [SiteContentExtractor] = [
        WikipediaExtractor(),
        GitHubExtractor(),
        StackOverflowExtractor(),
        VergeExtractor(),
        ZennExtractor(),
        MothershipExtractor(),
        TomsHardwareExtractor(),
        France24Extractor(),
        AppleExtractor(),
        ZDNETExtractor(),
        NineToFiveExtractor()
    ]

    public static func extractor(for url: URL) -> SiteContentExtractor? {
        all.first { $0.canHandle(url: url) }
    }
}
