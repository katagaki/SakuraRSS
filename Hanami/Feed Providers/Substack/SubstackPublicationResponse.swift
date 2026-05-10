import Foundation

public struct SubstackPublicationResponse: Decodable {
    public let logoURL: String?

    public enum CodingKeys: String, CodingKey {
        case logoURL = "logo_url"
    }
}
