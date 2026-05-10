import Foundation

public struct SubstackPublicProfile: Decodable {
    public let photoURL: String?
    public let primaryPublication: SubstackPrimaryPublication?

    public enum CodingKeys: String, CodingKey {
        case photoURL = "photo_url"
        case primaryPublication
    }
}

public struct SubstackPrimaryPublication: Decodable {
    public let logoURL: String?

    public enum CodingKeys: String, CodingKey {
        case logoURL = "logo_url"
    }
}
