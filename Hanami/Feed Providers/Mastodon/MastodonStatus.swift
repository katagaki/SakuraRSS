import Foundation

nonisolated struct MastodonContext: Decodable, Sendable {
    let ancestors: [MastodonStatus]
    let descendants: [MastodonStatus]
}

nonisolated struct MastodonStatus: Decodable, Sendable {
    let id: String
    let uri: String?
    let url: String?
    let content: String
    let createdAt: String?
    let inReplyToID: String?
    let account: MastodonAccount

    enum CodingKeys: String, CodingKey {
        case id, uri, url, content, account
        case createdAt = "created_at"
        case inReplyToID = "in_reply_to_id"
    }

    var createdDate: Date? {
        MastodonDate.parse(createdAt)
    }

    var displayAuthor: String {
        account.displayName.isEmpty ? "@\(account.acct)" : account.displayName
    }
}

nonisolated struct MastodonAccount: Decodable, Sendable {
    let username: String
    let acct: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case username, acct
        case displayName = "display_name"
    }
}

nonisolated enum MastodonDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
