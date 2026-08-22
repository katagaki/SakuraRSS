import Foundation

public struct SponsorSegment: Codable, Identifiable {
    public let UUID: String
    public let category: String
    public let startTime: Double
    public let endTime: Double

    public var id: String { UUID }

    public init(UUID: String, category: String, startTime: Double, endTime: Double) {
        self.UUID = UUID
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
    }

    private enum CodingKeys: String, CodingKey {
        case UUID
        case category
        case segment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        UUID = try container.decode(String.self, forKey: .UUID)
        category = try container.decode(String.self, forKey: .category)
        let bounds = try container.decode([Double].self, forKey: .segment)
        guard bounds.count >= 2, bounds[1] > bounds[0] else {
            throw DecodingError.dataCorruptedError(
                forKey: .segment,
                in: container,
                debugDescription: "Segment bounds are missing or out of order"
            )
        }
        startTime = bounds[0]
        endTime = bounds[1]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UUID, forKey: .UUID)
        try container.encode(category, forKey: .category)
        try container.encode([startTime, endTime], forKey: .segment)
    }
}

private struct DecodableSponsorSegment: Decodable {
    let segment: SponsorSegment?

    init(from decoder: Decoder) throws {
        segment = try? SponsorSegment(from: decoder)
    }
}

public enum SponsorBlockCategory: String, CaseIterable {
    case sponsor
    case selfpromo
    case interaction
    case intro
    case outro
    case preview
    case musicOfftopic = "music_offtopic"
    case filler

    public var displayName: String {
        switch self {
        case .sponsor: String(localized: "SponsorBlock.Category.Sponsor", table: "Podcast")
        case .selfpromo: String(localized: "SponsorBlock.Category.SelfPromo", table: "Podcast")
        case .interaction: String(localized: "SponsorBlock.Category.Interaction", table: "Podcast")
        case .intro: String(localized: "SponsorBlock.Category.Intro", table: "Podcast")
        case .outro: String(localized: "SponsorBlock.Category.Outro", table: "Podcast")
        case .preview: String(localized: "SponsorBlock.Category.Preview", table: "Podcast")
        case .musicOfftopic: String(localized: "SponsorBlock.Category.MusicOfftopic", table: "Podcast")
        case .filler: String(localized: "SponsorBlock.Category.Filler", table: "Podcast")
        }
    }
}

public enum SponsorBlockClient {

    public static func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = components.host?.lowercased() ?? ""

        if host.contains("youtube.com") {
            for prefix in ["/shorts/", "/live/", "/embed/"]
            where components.path.hasPrefix(prefix) {
                let identifier = String(components.path.dropFirst(prefix.count))
                    .split(separator: "/").first.map(String.init)
                if let identifier, !identifier.isEmpty {
                    return identifier
                }
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }

        if host.contains("youtu.be") {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }

        return nil
    }

    public static func fetchSegments(for videoID: String, categories: [String]) async -> [SponsorSegment] {
        guard !categories.isEmpty else { return [] }

        let categoriesJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: categories),
           let string = String(data: data, encoding: .utf8) {
            categoriesJSON = string
        } else {
            return []
        }

        guard let encodedCategories = categoriesJSON
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(
                string: "https://sponsor.ajay.app/api/skipSegments?videoID=\(videoID)&categories=\(encodedCategories)"
              ) else {
            return []
        }

        let request = URLRequest.sakura(url: url, timeoutInterval: 5)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }
            let decoded = try? JSONDecoder().decode([DecodableSponsorSegment].self, from: data)
            return decoded?.compactMap(\.segment) ?? []
        } catch {
            return []
        }
    }
}
