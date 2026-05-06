import Foundation

struct SubstackPublicProfile: Decodable {
    let photoURL: String?
    let primaryPublication: PrimaryPublication?

    struct PrimaryPublication: Decodable {
        let logoURL: String?

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case logoURL = "logo_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
        case primaryPublication
    }
}
