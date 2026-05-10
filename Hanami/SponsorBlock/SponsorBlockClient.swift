import Foundation

public struct SponsorSegment: Codable, Identifiable {
    public let UUID: String
    public let category: String
    public let segment: [Double]

    public var id: String { UUID }
    public var startTime: Double { segment[0] }
    public var endTime: Double { segment[1] }
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
            if components.path.hasPrefix("/shorts/") {
                let parts = components.path.split(separator: "/")
                if parts.count >= 2 {
                    return String(parts[1])
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
            return (try? JSONDecoder().decode([SponsorSegment].self, from: data)) ?? []
        } catch {
            return []
        }
    }
}
