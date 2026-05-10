import Foundation

struct SubstackPublicationResponse: Decodable {
    let logoURL: String?

    enum CodingKeys: String, CodingKey {
        case logoURL = "logo_url"
    }
}
