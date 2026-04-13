import Foundation

struct SponsorSegment: Codable, Identifiable {
    let UUID: String
    let category: String
    let segment: [Double]

    var id: String { UUID }
    var startTime: Double { segment[0] }
    var endTime: Double { segment[1] }
}

enum SponsorBlockCategory: String, CaseIterable {
    case sponsor
    case selfpromo
    case interaction
    case intro
    case outro
    case preview
    case musicOfftopic = "music_offtopic"
    case filler

    var displayName: String {
        switch self {
        case .sponsor: String(localized: "SponsorBlock.Category.Sponsor")
        case .selfpromo: String(localized: "SponsorBlock.Category.SelfPromo")
        case .interaction: String(localized: "SponsorBlock.Category.Interaction")
        case .intro: String(localized: "SponsorBlock.Category.Intro")
        case .outro: String(localized: "SponsorBlock.Category.Outro")
        case .preview: String(localized: "SponsorBlock.Category.Preview")
        case .musicOfftopic: String(localized: "SponsorBlock.Category.MusicOfftopic")
        case .filler: String(localized: "SponsorBlock.Category.Filler")
        }
    }
}

enum SponsorBlockClient {

    static func extractVideoID(from urlString: String) -> String? {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = components.host?.lowercased() ?? ""

        // youtube.com/watch?v=ID
        if host.contains("youtube.com") {
            if components.path.hasPrefix("/shorts/") {
                let parts = components.path.split(separator: "/")
                if parts.count >= 2 {
                    return String(parts[1])
                }
            }
            return components.queryItems?.first(where: { $0.name == "v" })?.value
        }

        // youtu.be/ID
        if host.contains("youtu.be") {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }

        return nil
    }

    static func fetchSegments(for videoID: String, categories: [String]) async -> [SponsorSegment] {
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
