import Foundation

struct SubstackPublicProfile: Decodable {
    let photoURL: String?
    let primaryPublication: SubstackPrimaryPublication?

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
        case primaryPublication
    }
}

struct SubstackPrimaryPublication: Decodable {
    let logoURL: String?

    enum CodingKeys: String, CodingKey {
        case logoURL = "logo_url"
    }
}
